# Vision nutrition benchmark

A **dev-only** harness to answer the question public leaderboards can't:
*which vision model is least wrong about **food**, in **our** pipeline?*

`vision_benchmark.py` sends each of your meal photos to several vision models —
using the **exact production prompt + `log_food` tool schema** imported from
`backend/src/app.py`, so the only variable is the model — then scores each
model's calorie/protein/sat-fat error against a ground-truth CSV, plus its
structured-call success rate and latency.

It is **not** part of the Lambda deploy, never calls the production proxy, and
uses your own API keys + your own photos. It does not touch the live
client↔server contract.

## Setup

```bash
pip install -r backend/tools/requirements-bench.txt

# Set only the keys for the models you want to test:
export ANTHROPIC_API_KEY=sk-ant-...   # sonnet, haiku
export GLM_API_KEY=...                 # glm, glm-flash (Z.ai)
export DASHSCOPE_API_KEY=...           # qwen          (Alibaba intl)
```

## Run

```bash
python backend/tools/vision_benchmark.py \
  --photos-dir ./meal_photos \
  --truth-csv  backend/tools/ground_truth.example.csv \
  --models sonnet,haiku,glm,qwen
```

Models whose API key is unset are skipped, so you can start with just
`--models sonnet,haiku` if Anthropic is all you have.

### Ground-truth CSV

Header required; one row per photo:

```
filename,calories,proteinG,satFatG[,name]
```

`filename` must match a file in `--photos-dir`. Supported image types:
jpg/jpeg/png/webp/gif. (The shipped app normalizes HEIC→JPEG at pick time, so
export your test set as JPEG.)

### Useful flags

- `--list` — show the model registry (keys, model ids, which env var, notes).
- `--limit N` — only run the first N photos (cheap smoke test).
- `--model-id glm=glm-4v-plus` — override a model id if a vendor renamed it.
- `--base-url qwen=https://...` — override a provider endpoint.

## Output

A per-model table: **n** photos, **tool✓** structured-call success rate,
**kcal MAE** (avg absolute calorie error), **kcal MAPE** (avg % error),
**prot/satf MAE** in grams, and mean latency. A few failures are printed so a
0% tool rate is never a silent mystery.

## Caveats

- **Benchmarks are a proxy, ground truth is hard.** Your "true" macros are
  themselves estimates — treat MAE as *relative* model ranking, not absolute
  truth. Bigger, more varied photo sets give a more trustworthy ranking.
- **GLM/Qwen model ids & endpoints drift.** The defaults are best-effort for
  mid-2026; if a call 404s, check the vendor docs and pass `--model-id` /
  `--base-url`.
- **Privacy.** GLM/Qwen endpoints run on third-party (incl. overseas) infra and
  free tiers may train on inputs. Use throwaway/your-own test photos here — do
  **not** pipe real users' meal photos to a provider you haven't vetted.
- **Production parity.** The Claude path sends the byte-identical request body
  from `app.build_request_body`. The OpenAI-compatible path translates the same
  tool schema + prompts to function-calling. The shipped app also *downscales*
  the photo before analysis; this harness sends the file as-is, so feed it
  similarly-sized images for a fair comparison.
```
