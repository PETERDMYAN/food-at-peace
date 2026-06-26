#!/usr/bin/env python3
"""Food-photo nutrition benchmark — Claude vs GLM vs Qwen (and friends).

There is no public benchmark for "estimate calories/protein/sat-fat from a
meal photo", so this script lets you build your own against *your* photos.
It fans each photo out to several vision models — using the EXACT production
prompt + ``log_food`` tool schema from ``backend/src/app.py`` so the only thing
that varies is the model — parses the structured estimate, and scores each
model's mean absolute error (MAE) against a ground-truth CSV plus its
tool-call success rate and latency.

This is a DEV TOOL. It is not deployed to Lambda, never touches the production
proxy, and uses your own API keys + your own test photos. Nothing here changes
the live client<->server contract.

----------------------------------------------------------------------------
USAGE
----------------------------------------------------------------------------
    pip install -r backend/tools/requirements-bench.txt

    # keys (only set the ones you want to test):
    export ANTHROPIC_API_KEY=sk-ant-...     # sonnet, haiku
    export GLM_API_KEY=...                   # glm, glm-flash  (Z.ai)
    export DASHSCOPE_API_KEY=...             # qwen            (Alibaba intl)

    python backend/tools/vision_benchmark.py \
        --photos-dir ./meal_photos \
        --truth-csv  ./backend/tools/ground_truth.example.csv \
        --models sonnet,haiku,glm,qwen

Ground-truth CSV columns (header required):
    filename,calories,proteinG,satFatG[,name]
A row whose photo is missing (or a photo with no row) is skipped with a note.

Models whose API key is unset are skipped automatically, so you can run just
Claude if that's all you have keys for.

NOTE on provider model IDs / endpoints: the GLM and Qwen entries below are
best-effort defaults for mid-2026. Vendors rename models and rotate endpoints
often — if a call 404s on the model id, check their docs and override with
``--model-id glm=<id>`` / ``--base-url glm=<url>`` (repeatable).
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

# --- Reuse the PRODUCTION prompt + tool schema (parity is the whole point) ----
# app.py is stdlib + lazy boto3, so importing it here pulls in no AWS deps.
_SRC = Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(_SRC))
import app  # noqa: E402  (after sys.path tweak)

# Pull the exact tool definition + prompts production sends to Claude. We build
# a throwaway request body and lift the pieces out, so this stays in lockstep
# with app.build_request_body without copy-pasting the schema.
_BODY = app.build_request_body("", "image/jpeg", "x")
_TOOL = _BODY["tools"][0]            # {name, description, input_schema}
_SYSTEM_PROMPT = app.SYSTEM_PROMPT
_USER_PROMPT = app.USER_PROMPT
_MAX_TOKENS = app.MAX_TOKENS
_TOOL_NAME = app.TOOL_NAME           # "log_food"

_MEDIA_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
}


# --- Model registry ----------------------------------------------------------
@dataclass
class ModelSpec:
    key: str            # short name used on the CLI
    provider: str       # "anthropic" | "openai_compat"
    model_id: str       # the API's model string
    key_env: str        # env var holding the API key
    base_url: str = ""  # for openai_compat providers
    note: str = ""


REGISTRY: dict[str, ModelSpec] = {
    "sonnet": ModelSpec("sonnet", "anthropic", "claude-sonnet-4-6",
                        "ANTHROPIC_API_KEY", note="current production default"),
    "haiku": ModelSpec("haiku", "anthropic", "claude-haiku-4-5",
                       "ANTHROPIC_API_KEY", note="~3x cheaper, same vendor/tool format"),
    "glm": ModelSpec("glm", "openai_compat", "glm-4.6v", "GLM_API_KEY",
                     base_url="https://api.z.ai/api/paas/v4",
                     note="Zhipu/Z.ai flagship vision"),
    "glm-flash": ModelSpec("glm-flash", "openai_compat", "glm-4.6v-flash",
                           "GLM_API_KEY", base_url="https://api.z.ai/api/paas/v4",
                           note="free tier — 9B, weakest"),
    "qwen": ModelSpec("qwen", "openai_compat", "qwen-vl-max", "DASHSCOPE_API_KEY",
                      base_url="https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
                      note="Alibaba Qwen-VL-Max (Singapore intl endpoint)"),
}


# --- Per-photo result --------------------------------------------------------
@dataclass
class Prediction:
    ok: bool
    latency_s: float
    calories: float | None = None
    proteinG: float | None = None
    satFatG: float | None = None
    error: str = ""


@dataclass
class ModelRun:
    spec: ModelSpec
    preds: dict[str, Prediction] = field(default_factory=dict)  # filename -> pred


# --- Helpers -----------------------------------------------------------------
def _encode(photo: Path) -> tuple[str, str]:
    media = _MEDIA_TYPES.get(photo.suffix.lower())
    if not media:
        raise ValueError(f"unsupported image type: {photo.suffix}")
    return base64.standard_b64encode(photo.read_bytes()).decode("ascii"), media


def _num(v) -> float | None:
    """Coerce a model-supplied number that may arrive as int/float/str."""
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _extract(d: dict) -> tuple[float | None, float | None, float | None]:
    return _num(d.get("calories")), _num(d.get("proteinG")), _num(d.get("satFatG"))


# --- Provider calls ----------------------------------------------------------
def call_anthropic(spec: ModelSpec, b64: str, media: str):
    """Send the EXACT production request body via the official Anthropic SDK."""
    from anthropic import Anthropic

    client = Anthropic(api_key=os.environ[spec.key_env])
    body = app.build_request_body(b64, media, spec.model_id)
    resp = client.messages.create(**body)
    for block in resp.content:
        if block.type == "tool_use" and block.name == _TOOL_NAME:
            return dict(block.input)
    raise RuntimeError("no log_food tool_use block in response")


def call_openai_compat(spec: ModelSpec, b64: str, media: str):
    """GLM / Qwen et al. via their OpenAI-compatible function-calling API,
    fed the same system/user prompt and the same tool schema (translated to
    OpenAI's `parameters` shape)."""
    from openai import OpenAI

    client = OpenAI(api_key=os.environ[spec.key_env], base_url=spec.base_url)
    tools = [{
        "type": "function",
        "function": {
            "name": _TOOL["name"],
            "description": _TOOL["description"],
            "parameters": _TOOL["input_schema"],
        },
    }]
    resp = client.chat.completions.create(
        model=spec.model_id,
        max_tokens=_MAX_TOKENS,
        tools=tools,
        tool_choice={"type": "function", "function": {"name": _TOOL_NAME}},
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": [
                {"type": "text", "text": _USER_PROMPT},
                {"type": "image_url",
                 "image_url": {"url": f"data:{media};base64,{b64}"}},
            ]},
        ],
    )
    calls = resp.choices[0].message.tool_calls
    if not calls:
        raise RuntimeError("model returned no tool call")
    return json.loads(calls[0].function.arguments)


def run_one(spec: ModelSpec, photo: Path) -> Prediction:
    b64, media = _encode(photo)
    t0 = time.monotonic()
    try:
        caller = call_anthropic if spec.provider == "anthropic" else call_openai_compat
        out = caller(spec, b64, media)
        cal, pro, sat = _extract(out)
        dt = time.monotonic() - t0
        if cal is None or pro is None or sat is None:
            return Prediction(False, dt, cal, pro, sat,
                              "missing one of calories/proteinG/satFatG")
        return Prediction(True, dt, cal, pro, sat)
    except Exception as e:  # noqa: BLE001 — a benchmark must survive any provider error
        return Prediction(False, time.monotonic() - t0, error=f"{type(e).__name__}: {e}")


# --- Ground truth ------------------------------------------------------------
def load_truth(csv_path: Path) -> dict[str, dict]:
    import csv

    truth: dict[str, dict] = {}
    with csv_path.open(newline="") as f:
        for row in csv.DictReader(f):
            fn = (row.get("filename") or "").strip()
            if not fn:
                continue
            truth[fn] = {
                "calories": _num(row.get("calories")),
                "proteinG": _num(row.get("proteinG")),
                "satFatG": _num(row.get("satFatG")),
                "name": (row.get("name") or "").strip(),
            }
    return truth


# --- Scoring + reporting -----------------------------------------------------
def _mae(pairs: list[tuple[float, float]]) -> float | None:
    return sum(abs(p - t) for p, t in pairs) / len(pairs) if pairs else None


def _mape(pairs: list[tuple[float, float]]) -> float | None:
    usable = [(p, t) for p, t in pairs if t]
    return (100 * sum(abs(p - t) / t for p, t in usable) / len(usable)
            if usable else None)


def report(runs: list[ModelRun], truth: dict[str, dict]) -> None:
    def fmt(x, suffix=""):
        return f"{x:.0f}{suffix}" if x is not None else "  —"

    print("\n" + "=" * 92)
    print("VISION NUTRITION BENCHMARK  —  lower MAE/MAPE is better")
    print("=" * 92)
    header = (f"{'model':<11} {'n':>3} {'tool✓':>6} "
              f"{'kcal MAE':>9} {'kcal MAPE':>10} "
              f"{'prot MAE':>9} {'satf MAE':>9} {'lat(s)':>7}")
    print(header)
    print("-" * 92)

    for run in runs:
        cal_pairs, pro_pairs, sat_pairs, lats = [], [], [], []
        attempted = ok = 0
        for fn, t in truth.items():
            pred = run.preds.get(fn)
            if pred is None:
                continue
            attempted += 1
            lats.append(pred.latency_s)
            if not pred.ok:
                continue
            ok += 1
            if t["calories"] is not None:
                cal_pairs.append((pred.calories, t["calories"]))
            if t["proteinG"] is not None:
                pro_pairs.append((pred.proteinG, t["proteinG"]))
            if t["satFatG"] is not None:
                sat_pairs.append((pred.satFatG, t["satFatG"]))

        tool_rate = f"{(100 * ok / attempted):.0f}%" if attempted else "—"
        mape = _mape(cal_pairs)
        mean_lat = sum(lats) / len(lats) if lats else None
        print(f"{run.spec.key:<11} {attempted:>3} {tool_rate:>6} "
              f"{fmt(_mae(cal_pairs)):>9} "
              f"{(f'{mape:.0f}%' if mape is not None else '  —'):>10} "
              f"{fmt(_mae(pro_pairs), 'g'):>9} {fmt(_mae(sat_pairs), 'g'):>9} "
              f"{(f'{mean_lat:.1f}' if mean_lat is not None else '—'):>7}")

    print("-" * 92)
    # Surface a couple of failures so a 0% tool rate isn't a silent mystery.
    shown = 0
    for run in runs:
        for fn, pred in run.preds.items():
            if not pred.ok and shown < 6:
                print(f"  ⚠ {run.spec.key}/{fn}: {pred.error}")
                shown += 1
    print("=" * 92)
    print("kcal MAE = avg absolute calorie error; MAPE = avg % error; "
          "prot/satf MAE in grams. tool✓ = structured-call success rate.\n")


# --- Main --------------------------------------------------------------------
def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--photos-dir", type=Path)
    p.add_argument("--truth-csv", type=Path)
    p.add_argument("--models", default="sonnet,haiku,glm,qwen",
                   help="comma list of registry keys (default: %(default)s)")
    p.add_argument("--limit", type=int, default=0,
                   help="cap number of photos (0 = all)")
    p.add_argument("--model-id", action="append", default=[],
                   metavar="key=id", help="override a model id, e.g. glm=glm-4v-plus")
    p.add_argument("--base-url", action="append", default=[],
                   metavar="key=url", help="override a provider base url")
    p.add_argument("--list", action="store_true", help="list the registry and exit")
    args = p.parse_args(argv)

    if args.list:
        for spec in REGISTRY.values():
            print(f"  {spec.key:<11} {spec.provider:<13} {spec.model_id:<18} "
                  f"key={spec.key_env}  {spec.note}")
        return 0

    if not args.photos_dir or not args.truth_csv:
        p.error("--photos-dir and --truth-csv are required (unless --list)")

    for ov in args.model_id:
        k, _, v = ov.partition("=")
        if k in REGISTRY and v:
            REGISTRY[k].model_id = v
    for ov in args.base_url:
        k, _, v = ov.partition("=")
        if k in REGISTRY and v:
            REGISTRY[k].base_url = v

    truth = load_truth(args.truth_csv)
    if not truth:
        print(f"No rows in {args.truth_csv}", file=sys.stderr)
        return 1

    # Resolve photos that have both a file on disk and a truth row.
    photos: list[Path] = []
    for fn in truth:
        photo = args.photos_dir / fn
        if photo.exists():
            photos.append(photo)
        else:
            print(f"  (skip: no photo for truth row '{fn}')", file=sys.stderr)
    if args.limit:
        photos = photos[:args.limit]
    if not photos:
        print("No photos matched the truth CSV.", file=sys.stderr)
        return 1

    # Select models whose API key is actually set.
    runs: list[ModelRun] = []
    for key in [k.strip() for k in args.models.split(",") if k.strip()]:
        spec = REGISTRY.get(key)
        if not spec:
            print(f"  (skip: unknown model '{key}')", file=sys.stderr)
            continue
        if not os.environ.get(spec.key_env):
            print(f"  (skip: {key} — {spec.key_env} not set)", file=sys.stderr)
            continue
        runs.append(ModelRun(spec))
    if not runs:
        print("No runnable models (set the relevant API keys).", file=sys.stderr)
        return 1

    print(f"Benchmarking {len(runs)} model(s) on {len(photos)} photo(s)...")
    for run in runs:
        print(f"\n→ {run.spec.key} ({run.spec.model_id})")
        for photo in photos:
            pred = run_one(run.spec, photo)
            run.preds[photo.name] = pred
            status = "ok " if pred.ok else "ERR"
            detail = (f"{pred.calories:.0f} kcal" if pred.ok
                      else pred.error[:60])
            print(f"   [{status}] {photo.name:<28} {detail}  ({pred.latency_s:.1f}s)")

    report(runs, truth)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
