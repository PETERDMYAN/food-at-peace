#!/usr/bin/env python3
"""Surgically deploy the Circle push-localization + reactor-name fix to PROD.

Isolated, dependency-safe update of ONLY the Posts + Circle Lambdas on the prod
stack (`food-at-peace-vision-proxy`), mirroring the prior posts-only prod deploys
(`update-function-code`, no full `sam deploy`). For each function it:

  1. downloads the function's CURRENT deployment package,
  2. overwrites just the changed handler files (posts.py / circle.py / apns.py)
     and adds the new pushmsg.py — **leaving every bundled dependency
     (httpx, ecdsa, PyJWT, ...) exactly as sam build produced it**, and
  3. re-uploads.

This avoids the classic footgun of zipping `src/*.py` alone, which would strip
the pip-installed deps and break the function.

All four files are read from backend/src/. Run from anywhere with valid prod AWS
credentials:

    python3 backend/scripts/deploy_push_l10n_prod.py            # deploy
    python3 backend/scripts/deploy_push_l10n_prod.py --dry-run  # inspect only

Safe to re-run (idempotent — same bytes → same result).
"""
import argparse
import io
import os
import sys
import time
import urllib.request
import zipfile

import boto3

REGION = "ap-southeast-1"
STACK = "food-at-peace-vision-proxy"  # PROD (the user explicitly approved prod)
FUNCTIONS = ["PostsFunction", "CircleFunction"]
PATCH_FILES = ["posts.py", "circle.py", "apns.py", "pushmsg.py"]

SRC = os.path.join(os.path.dirname(__file__), "..", "src")


def _local_sources():
    out = {}
    for name in PATCH_FILES:
        with open(os.path.join(SRC, name), "rb") as f:
            out[name] = f.read()
    return out


def _patched_zip(original_bytes, sources):
    """Return a new zip = original with PATCH_FILES overwritten/added at root."""
    src_in = zipfile.ZipFile(io.BytesIO(original_bytes))
    buf = io.BytesIO()
    seen = set()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as dst:
        for info in src_in.infolist():
            if info.filename in sources:
                dst.writestr(info, sources[info.filename])  # overwrite in place
                seen.add(info.filename)
            else:
                dst.writestr(info, src_in.read(info.filename))  # preserve verbatim
        for name, data in sources.items():
            if name not in seen:  # brand-new file (pushmsg.py)
                dst.writestr(name, data)
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cf = boto3.client("cloudformation", region_name=REGION)
    lam = boto3.client("lambda", region_name=REGION)
    sources = _local_sources()
    print(f"Local source files: {', '.join(PATCH_FILES)}")

    for logical in FUNCTIONS:
        fn = cf.describe_stack_resource(
            StackName=STACK, LogicalResourceId=logical
        )["StackResourceDetail"]["PhysicalResourceId"]
        meta = lam.get_function(FunctionName=fn)
        loc = meta["Code"]["Location"]
        before = meta["Configuration"]["CodeSha256"]
        print(f"\n{logical} -> {fn}\n  current sha256: {before}")

        original = urllib.request.urlopen(loc, timeout=60).read()
        names = set(zipfile.ZipFile(io.BytesIO(original)).namelist())
        missing = [n for n in PATCH_FILES if n not in names and n != "pushmsg.py"]
        if missing:
            print(f"  !! expected files not at zip root: {missing} — aborting")
            sys.exit(2)
        patched = _patched_zip(original, sources)
        print(f"  package: {len(original)} -> {len(patched)} bytes "
              f"(adds pushmsg.py: {'pushmsg.py' not in names})")

        if args.dry_run:
            print("  [dry-run] not uploading")
            continue

        lam.update_function_code(FunctionName=fn, ZipFile=patched, Publish=False)
        lam.get_waiter("function_updated").wait(FunctionName=fn)
        after = lam.get_function(FunctionName=fn)["Configuration"]["CodeSha256"]
        print(f"  new sha256: {after}  {'(changed)' if after != before else '(UNCHANGED?!)'}")
        time.sleep(1)

    print("\nDone." if not args.dry_run else "\nDry run complete.")


if __name__ == "__main__":
    main()
