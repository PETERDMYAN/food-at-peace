"""Account deletion (AWS Lambda + DynamoDB) — App Store Guideline 5.1.1(v).

POST /account/delete  (Authorization: Bearer <sessionToken>)
  returns: {"deleted": <number of rows removed>}

Deletes every row the authenticated user owns in the sync table (food, weight,
profile — including tombstones), which is all the server-side data we hold for
them.

Sessions are stateless signed tokens, so deletion also writes a per-user
revocation marker (sk = "account#deleted", minIat = now): /sync and this
endpoint reject any token minted before it, which cuts off the user's *other*
still-signed-in devices (and any stolen pre-deletion token) instead of letting
their next sync silently re-create the "deleted" account. A later fresh
sign-in mints a token with a newer iat, which passes the check.

The marker is written before the row deletes so requests racing the deletion
are rejected as early as possible; the endpoint is idempotent (deleting an
already-empty account returns 200 with deleted=0).
"""

import os
import time

from common import ProxyError, _get_secret, _header, _parse_body, _response  # noqa: F401
from session import verify_session_token

TABLE_NAME = os.environ.get("SYNC_TABLE", "")
# Optional: the isolated Beans ledger table. When set, deletion also clears it so
# no server-side data outlives the account. Absent → the beans clear is skipped.
BEANS_TABLE = os.environ.get("BEANS_TABLE", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)

# Revocation marker row. Unreachable via /sync's record keys: collection rows
# are "food#<id>"/"weight#<id>" and the singleton is "profile".
DELETED_MARKER_SK = "account#deleted"


def check_token_not_revoked(claims, marker):
    """Reject tokens minted before the user's deletion marker (if any)."""
    if marker is None:
        return
    if int(claims.get("iat") or 0) < int(marker.get("minIat") or 0):
        raise ProxyError(401, "Session expired. Please sign in again.")


class _DeleteStore:
    """Thin DynamoDB wrapper. Swapped for an in-memory fake in tests."""

    def __init__(self, table):
        self._t = table

    def get(self, user_id, sk):
        return self._t.get_item(Key={"userId": user_id, "sk": sk}).get("Item")

    def put(self, item):
        self._t.put_item(Item=item)

    def keys_for_user(self, user_id):
        from boto3.dynamodb.conditions import Key

        keys = []
        kwargs = {
            "KeyConditionExpression": Key("userId").eq(user_id),
            "ProjectionExpression": "sk",
        }
        while True:
            resp = self._t.query(**kwargs)
            keys.extend(item["sk"] for item in resp.get("Items", []))
            start = resp.get("LastEvaluatedKey")
            if not start:
                return keys
            kwargs["ExclusiveStartKey"] = start

    def delete_many(self, user_id, sks):
        # BatchWriteItem (25/request, handled by batch_writer) keeps even large
        # accounts well inside the Lambda timeout.
        with self._t.batch_writer() as batch:
            for sk in sks:
                batch.delete_item(Key={"userId": user_id, "sk": sk})


_store_singleton = None
_beans_store_singleton = None


def _store():
    global _store_singleton
    if _store_singleton is None:
        import boto3  # lazy, like common._ssm_client

        _store_singleton = _DeleteStore(boto3.resource("dynamodb").Table(TABLE_NAME))
    return _store_singleton


def _beans_store():
    """Store for the user's Beans ledger, or None when no Beans table is set."""
    global _beans_store_singleton
    if not BEANS_TABLE:
        return None
    if _beans_store_singleton is None:
        import boto3

        _beans_store_singleton = _DeleteStore(
            boto3.resource("dynamodb").Table(BEANS_TABLE)
        )
    return _beans_store_singleton


def _clear_beans(user_id):
    """Best-effort: drop the user's Beans ledger (isolated table).

    Runs AFTER the sync-data delete + revocation marker — the Guideline
    5.1.1(v)-critical path. The marker now rejects this same token, so the
    request can't be retried as-is; a hiccup clearing the secondary table must
    never raise and fail the (already-completed) account deletion.
    """
    beans = _beans_store()
    if beans is None:
        return
    try:
        beans.delete_many(user_id, beans.keys_for_user(user_id))
    except Exception:  # noqa: BLE001 — never fail deletion on the secondary table
        pass


def _bearer(event):
    raw = _header(event, "authorization") or ""
    if raw.lower().startswith("bearer "):
        token = raw[7:].strip()
        if token:
            return token
    raise ProxyError(401, "Not authenticated.")


def handler(event, context):
    try:
        token = _bearer(event)
        signing_key = _get_secret(SESSION_KEY_PARAM)
        claims = verify_session_token(token, signing_key)
        user_id = claims.get("sub")
        if not user_id:
            raise ProxyError(401, "Not authenticated.")

        store = _store()
        # A token minted before a previous deletion can't delete the account a
        # fresh sign-in may have re-created since.
        check_token_not_revoked(claims, store.get(user_id, DELETED_MARKER_SK))

        keys = [sk for sk in store.keys_for_user(user_id) if sk != DELETED_MARKER_SK]
        # Marker first: from this moment /sync rejects every pre-deletion token.
        # updatedAt=0 keeps the marker invisible to /sync's delta listing
        # (which skips rows at-or-below the client's cursor).
        store.put(
            {
                "userId": user_id,
                "sk": DELETED_MARKER_SK,
                "type": "account",
                "minIat": int(time.time()),
                "updatedAt": 0,
            }
        )
        store.delete_many(user_id, keys)
        # Also clear the isolated Beans ledger (best-effort; see _clear_beans).
        _clear_beans(user_id)
        return _response(200, {"deleted": len(keys)})
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
