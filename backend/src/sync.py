"""Per-user cloud sync (AWS Lambda + DynamoDB).

One authenticated, bidirectional delta endpoint: the app sends the records it
changed since its last sync plus that cursor; we apply them last-write-wins,
then return everything for that user changed since the cursor (plus a new
cursor). Authentication is the app session token minted by auth.py.

POST /sync  (Authorization: Bearer <sessionToken>)
  body:    {"since": <epochMs>, "changes": {"food":[rec], "weight":[rec], "profile": rec|null}}
  returns: {"serverTime": <epochMs>, "changes": {"food":[rec], "weight":[rec], "profile": rec|null}}

A record is {"id", "updatedAt" (epochMs), "deleted" (bool), "data" (object)}.
Deletions travel as tombstones (deleted=true) so they propagate across devices.
The record payload is stored as a JSON string so DynamoDB never sees nested
floats (avoids Decimal round-tripping); only `updatedAt` is a Number.
"""

import json
import os
import time

from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

TABLE_NAME = os.environ.get("SYNC_TABLE", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)

# Record kinds. food/weight are collections (keyed by id); profile is a per-user
# singleton.
_COLLECTIONS = ("food", "weight")
_SINGLETONS = ("profile",)


class _DynamoStore:
    """Thin DynamoDB wrapper. Swapped for an in-memory fake in tests."""

    def __init__(self, table):
        self._t = table

    def get(self, user_id, sk):
        return self._t.get_item(Key={"userId": user_id, "sk": sk}).get("Item")

    def put(self, item):
        self._t.put_item(Item=item)

    def list_for_user(self, user_id):
        from boto3.dynamodb.conditions import Key

        items = []
        kwargs = {"KeyConditionExpression": Key("userId").eq(user_id)}
        while True:
            resp = self._t.query(**kwargs)
            items.extend(resp.get("Items", []))
            start = resp.get("LastEvaluatedKey")
            if not start:
                return items
            kwargs["ExclusiveStartKey"] = start


_store_singleton = None


def _store():
    global _store_singleton
    if _store_singleton is None:
        import boto3  # lazy, like common._ssm_client

        _store_singleton = _DynamoStore(boto3.resource("dynamodb").Table(TABLE_NAME))
    return _store_singleton


def _now_ms():
    return int(time.time() * 1000)


def _sk(rtype, rid):
    return rtype if rtype in _SINGLETONS else f"{rtype}#{rid}"


def _bearer(event):
    raw = _header(event, "authorization") or ""
    if raw.lower().startswith("bearer "):
        token = raw[7:].strip()
        if token:
            return token
    raise ProxyError(401, "Not authenticated.")


def _apply_one(store, user_id, rtype, rid, record):
    """Last-write-wins: write only if the incoming record is newer-or-equal than
    what's stored. (Read-then-write — fine for a single user's occasional sync;
    a conditional write could harden against concurrent same-record writes.)"""
    incoming = int(record.get("updatedAt") or 0)
    sk = _sk(rtype, rid)
    existing = store.get(user_id, sk)
    if existing is not None and int(existing["updatedAt"]) >= incoming:
        return
    store.put(
        {
            "userId": user_id,
            "sk": sk,
            "type": rtype,
            "data": json.dumps(record.get("data") or {}),
            "updatedAt": incoming,
            "deleted": bool(record.get("deleted", False)),
        }
    )


def _to_record(item):
    sk = item["sk"]
    rid = sk.split("#", 1)[1] if "#" in sk else sk
    return {
        "id": rid,
        "updatedAt": int(item["updatedAt"]),
        "deleted": bool(item.get("deleted", False)),
        "data": json.loads(item["data"]) if item.get("data") else {},
    }


def handler(event, context):
    try:
        token = _bearer(event)
        signing_key = _get_secret(SESSION_KEY_PARAM)
        claims = verify_session_token(token, signing_key)
        user_id = claims.get("sub")
        if not user_id:
            raise ProxyError(401, "Not authenticated.")

        body = _parse_body(event)
        since = int(body.get("since") or 0)
        incoming = body.get("changes") or {}
        store = _store()

        # 1) Apply the client's changes (LWW).
        for rtype in _COLLECTIONS:
            for record in incoming.get(rtype) or []:
                rid = record.get("id")
                if rid:
                    _apply_one(store, user_id, rtype, rid, record)
        profile = incoming.get("profile")
        if profile:
            _apply_one(store, user_id, "profile", "profile", profile)

        # 2) Return everything changed since the client's cursor.
        out = {"food": [], "weight": [], "profile": None}
        for item in store.list_for_user(user_id):
            if int(item["updatedAt"]) <= since:
                continue
            record = _to_record(item)
            rtype = item.get("type")
            if rtype in _COLLECTIONS:
                out[rtype].append(record)
            elif rtype == "profile":
                out["profile"] = record

        return _response(200, {"serverTime": _now_ms(), "changes": out})
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
