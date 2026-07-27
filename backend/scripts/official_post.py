#!/usr/bin/env python3
"""Publish a photo + text post AS an official account — the owner-only push tool.
`--handle` picks WHICH official account (Eva and Roro are DISTINCT accounts);
defaults to `eva`. Hits POST /circle/official-post (admin-token gated).

Usage:
  python official_post.py --image PATH --text "CAPTION"                 # as Eva, → v2
  python official_post.py --image PATH --text "CAPTION" --prod          # as Eva, → prod
  python official_post.py --image PATH --text "CAPTION" --handle roro   # as Roro
  python official_post.py --image PATH --text "CAPTION" --base URL --token TOK

The admin token is read from SSM (/food-at-peace/admin-token, shared by both
stacks) unless --token is given. The post is shown under the account's live name
and shares the Circle 30-day TTL.
"""
import argparse
import base64
import json
import subprocess
import sys
import urllib.error
import urllib.request

V2 = "https://p21hoawoi5.execute-api.ap-southeast-1.amazonaws.com"
PROD = "https://6m19l2b025.execute-api.ap-southeast-1.amazonaws.com"


def ssm_admin_token():
    out = subprocess.check_output(
        [
            "aws", "ssm", "get-parameter", "--name", "/food-at-peace/admin-token",
            "--with-decryption", "--region", "ap-southeast-1",
            "--query", "Parameter.Value", "--output", "text",
        ]
    )
    return out.decode().strip()


def main():
    ap = argparse.ArgumentParser(description="Push a photo + text post as the official 'Eva' account.")
    ap.add_argument("--image", required=True, help="path to the photo (jpg/png)")
    ap.add_argument("--text", required=True, help="the caption shown on the post")
    ap.add_argument("--handle", default="eva", help="which official account to post as (eva | roro)")
    ap.add_argument("--base", help="API base URL (overrides --prod/v2 default)")
    ap.add_argument("--prod", action="store_true", help="target the LIVE prod stack")
    ap.add_argument("--token", help="admin token (default: read from SSM)")
    a = ap.parse_args()

    base = a.base or (PROD if a.prod else V2)
    token = a.token or ssm_admin_token()
    with open(a.image, "rb") as f:
        img = base64.b64encode(f.read()).decode()

    body = json.dumps({"image": img, "text": a.text, "handle": a.handle}).encode()
    req = urllib.request.Request(
        f"{base}/circle/official-post",
        data=body,
        method="POST",
        headers={"content-type": "application/json", "x-admin-token": token},
    )
    try:
        resp = json.load(urllib.request.urlopen(req, timeout=60))
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()[:600]}", file=sys.stderr)
        sys.exit(1)
    print(
        f"posted as {resp.get('author')!r}: postId={resp.get('postId')} "
        f"expiresAt={resp.get('expiresAt')}  ({base})"
    )


if __name__ == "__main__":
    main()
