"""Per-user Beans ledger (server-side, append-only).

GET  /beans  (Authorization: Bearer <sessionToken>) -> {"ledger": [txn, ...]}
POST /beans  (Authorization: Bearer <sessionToken>)  body {"txns": [txn, ...]}
     -> appends any new transactions (idempotent by id) -> {"ledger": [txn, ...]}
POST /beans/grant  (x-admin-token)  body {"handle", "amount", "note"?, "txnId"?}
     -> owner-only: resolve @handle -> userId, append a grant txn -> {userId, balance, txnId}

A txn is the client's BeanTransaction JSON: {id, type, amount, ts, note?, price?}.
Beans transactions (grant / spend / purchase / refund) are immutable, so a write
is idempotent by id and a read returns the union — the balance is the signed sum
of `amount`. The ledger is keyed to the account, so Beans follow the user across
devices. Isolated from the food/weight/profile sync (its own table + endpoint).
"""

import json
import os
import time
from datetime import datetime, timezone

from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

# The app's BeanTransaction model: `ts` is parsed as a STRING and `type` must be
# one of these (an unknown type silently becomes "spend" client-side).
_KNOWN_TYPES = {"signupGrant", "spend", "purchase", "refund"}

TABLE_NAME = os.environ.get("BEANS_TABLE", "")
CIRCLE_TABLE = os.environ.get("CIRCLE_TABLE", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)
ADMIN_TOKEN_PARAM = os.environ.get("ADMIN_TOKEN_PARAM", "/food-at-peace/admin-token")


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

        _store_singleton = _DynamoStore(
            boto3.resource("dynamodb").Table(TABLE_NAME)
        )
    return _store_singleton


def _bearer(event):
    raw = _header(event, "authorization") or ""
    if raw.lower().startswith("bearer "):
        token = raw[7:].strip()
        if token:
            return token
    raise ProxyError(401, "Not authenticated.")


def _method(event):
    http = (event.get("requestContext") or {}).get("http") or {}
    return (http.get("method") or event.get("httpMethod") or "GET").upper()


def _admin_ok(event):
    """True when the request carries the owner-only admin token."""
    tok = _header(event, "x-admin-token") or ""
    try:
        return bool(tok) and tok == _get_secret(ADMIN_TOKEN_PARAM)
    except Exception:  # noqa: BLE001 — any secret-fetch failure → not authorised
        return False


def _resolve_handle(handle):
    """An @handle (with/without '@', case-insensitive) → its userId, or None.
    Reads the circle handle directory (pk='handle#<handle>', sk='handle')."""
    h = handle.strip().lstrip("@").lower()
    if not h or not CIRCLE_TABLE:
        return None
    import boto3

    item = (
        boto3.resource("dynamodb")
        .Table(CIRCLE_TABLE)
        .get_item(Key={"pk": f"handle#{h}", "sk": "handle"})
        .get("Item")
    )
    return (item or {}).get("userId")


def _balance(store, user_id):
    return sum(
        json.loads(i["txn"]).get("amount", 0)
        for i in store.list_for_user(user_id)
        if i.get("txn")
    )


def _iso(ts):
    """A numeric epoch ts (ms or s) → ISO-8601 string."""
    try:
        secs = ts / 1000 if ts > 1_000_000_000_000 else ts
        return datetime.fromtimestamp(secs, tz=timezone.utc).isoformat()
    except Exception:  # noqa: BLE001 — never let a bad ts break the ledger
        return "2026-01-01T00:00:00+00:00"


def _normalize(txn):
    """Defensive: the shipped app casts `ts` as a String and maps an unknown
    `type` to a spend, so a numeric ts or an off-model type (e.g. from an early
    admin grant) would corrupt its parse/balance. Coerce a numeric ts to an ISO
    string and an unknown type to a positive 'purchase' on the way out —
    backward-compatible, since the client always expected those shapes."""
    ts = txn.get("ts")
    if isinstance(ts, (int, float)):
        txn["ts"] = _iso(ts)
    if txn.get("type") not in _KNOWN_TYPES:
        txn["type"] = "purchase"
    return txn


def grant(event):
    """Owner-only: credit a user's Beans ledger by @handle. Gated by the admin
    token (NOT a user session). Append-only + idempotent by txn id, so a repeat
    with the same txnId is a no-op."""
    if not _admin_ok(event):
        raise ProxyError(403, "Forbidden.")
    body = _parse_body(event)
    handle = (body.get("handle") or "").strip()
    amount = int(body.get("amount") or 0)
    note = ((body.get("note") or "").strip() or "Admin grant")[:120]
    if not handle:
        raise ProxyError(400, "Missing handle.")
    if amount == 0:
        raise ProxyError(400, "Amount must be non-zero.")
    user_id = _resolve_handle(handle)
    if not user_id:
        raise ProxyError(404, "No account for that handle.")
    store = _store()
    txn_id = (body.get("txnId") or "").strip() or f"admingrant-{user_id}-{int(time.time())}"
    if txn_id not in {i["sk"] for i in store.list_for_user(user_id)}:
        store.put(
            {
                "userId": user_id,
                "sk": txn_id,
                "txn": json.dumps(
                    {
                        "id": txn_id,
                        "type": "purchase",  # a known positive type the app sums
                        "amount": amount,
                        "ts": datetime.now(timezone.utc).isoformat(),
                        "note": note,
                    }
                ),
            }
        )
    return {"userId": user_id, "balance": _balance(store, user_id), "txnId": txn_id}


def handler(event, context):
    try:
        http = (event.get("requestContext") or {}).get("http") or {}
        if (http.get("path") or "").rsplit("/", 1)[-1] == "grant":
            return _response(200, grant(event))  # owner-only, admin-token gated
        token = _bearer(event)
        claims = verify_session_token(token, _get_secret(SESSION_KEY_PARAM))
        user_id = claims.get("sub")
        if not user_id:
            raise ProxyError(401, "Not authenticated.")
        store = _store()

        # Load the account's ledger once (this is also the GET response body).
        # Normalize on read so any legacy/off-model row stays parseable client-side.
        ledger = [
            _normalize(json.loads(i["txn"]))
            for i in store.list_for_user(user_id)
            if i.get("txn")
        ]

        if _method(event) == "POST":
            body = _parse_body(event)
            ids = {t.get("id") for t in ledger if t.get("id")}
            has_grant = any(t.get("type") == "signupGrant" for t in ledger)
            for txn in body.get("txns") or []:
                tid = txn.get("id")
                if not tid or tid in ids:
                    continue  # append-only + idempotent: never overwrite an id
                # One welcome grant per account, even though every device grants
                # its own local 100 on first launch (the union would double it).
                if txn.get("type") == "signupGrant":
                    if has_grant:
                        continue
                    has_grant = True
                store.put({"userId": user_id, "sk": tid, "txn": json.dumps(txn)})
                ids.add(tid)
                ledger.append(txn)

        return _response(200, {"ledger": ledger})
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
