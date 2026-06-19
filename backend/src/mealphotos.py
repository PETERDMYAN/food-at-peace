"""Food at Peace — private per-user meal-photo store (AWS Lambda).

Full-resolution meal photos kept DURABLY in S3 (no TTL), keyed by the food-entry
id and scoped to the signed-in user. Unlike the ephemeral Circle feed, these
never expire — they're the user's own photos, restored on a new device / after a
reinstall (the synced `photoThumb` on the entry is a small fast/offline preview;
this is the crisp original). The client uploads + downloads via **presigned
URLs**, so a full-size photo never hits the Lambda's 6 MB request limit and never
touches DynamoDB's 400 KB row limit. Session-token auth (same HS256 token as
/sync); a user can only ever read/write keys under their own id.

Routes:
  POST /photo/put-url   {entryId, mediaType?}   -> {url}                presigned PUT (15 min)
  POST /photo/get-urls  {entryIds: [...]}        -> {urls: {entryId:url}} presigned GET (6h)
  POST /photo/delete    {entryId}                -> {ok}

S3 key: meal/<userId>/<entryId>.jpg
"""

import os
import re

from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

MEAL_PHOTOS_BUCKET = os.environ.get("MEAL_PHOTOS_BUCKET", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)

PUT_URL_TTL = 15 * 60  # client uploads right after saving the meal
GET_URL_TTL = 6 * 60 * 60  # client caches the download locally
MAX_GET_BATCH = 100
_ID_RE = re.compile(r"[^A-Za-z0-9_-]")

_s3 = None


def _s3c():
    global _s3
    if _s3 is None:
        import boto3

        _s3 = boto3.client("s3")
    return _s3


def _me(event):
    raw = _header(event, "authorization") or ""
    token = raw[7:].strip() if raw.lower().startswith("bearer ") else ""
    if not token:
        raise ProxyError(401, "Not authenticated.")
    uid = verify_session_token(token, _get_secret(SESSION_KEY_PARAM)).get("sub")
    if not uid:
        raise ProxyError(401, "Not authenticated.")
    return uid


def _safe_id(raw):
    """A key-safe entry id (strips anything that could escape the user's prefix)."""
    cleaned = _ID_RE.sub("", str(raw or ""))
    if not cleaned:
        raise ProxyError(400, "Missing or invalid entryId.")
    return cleaned[:128]


def _key(uid, entry_id):
    # uid comes from the verified token; entry_id is sanitized — a user can only
    # ever address objects under their own meal/<uid>/ prefix.
    return f"meal/{uid}/{entry_id}.jpg"


def put_url(uid, body):
    entry_id = _safe_id(body.get("entryId"))
    media = body.get("mediaType") or "image/jpeg"
    url = _s3c().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": MEAL_PHOTOS_BUCKET,
            "Key": _key(uid, entry_id),
            "ContentType": media,
        },
        ExpiresIn=PUT_URL_TTL,
    )
    return {"url": url}


def get_urls(uid, body):
    ids = body.get("entryIds") or []
    if not isinstance(ids, list):
        raise ProxyError(400, "entryIds must be a list.")
    urls = {}
    for raw in ids[:MAX_GET_BATCH]:
        try:
            entry_id = _safe_id(raw)
        except ProxyError:
            continue
        urls[str(raw)] = _s3c().generate_presigned_url(
            "get_object",
            Params={"Bucket": MEAL_PHOTOS_BUCKET, "Key": _key(uid, entry_id)},
            ExpiresIn=GET_URL_TTL,
        )
    return {"urls": urls}


def delete(uid, body):
    entry_id = _safe_id(body.get("entryId"))
    _s3c().delete_object(Bucket=MEAL_PHOTOS_BUCKET, Key=_key(uid, entry_id))
    return {"ok": True}


def handler(event, context):
    try:
        uid = _me(event)
        http = event.get("requestContext", {}).get("http", {})
        path = (http.get("path") or "").rsplit("/", 1)[-1]
        body = _parse_body(event)
        if path == "put-url":
            return _response(200, put_url(uid, body))
        if path == "get-urls":
            return _response(200, get_urls(uid, body))
        if path == "delete":
            return _response(200, delete(uid, body))
        raise ProxyError(404, "Unknown action.")
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(500, {"error": {"message": "Unexpected error."}})
