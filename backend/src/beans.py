"""Per-user Beans ledger (server-side, append-only).

GET  /beans  (Authorization: Bearer <sessionToken>) -> {"ledger": [txn, ...]}
POST /beans  (Authorization: Bearer <sessionToken>)  body {"txns": [txn, ...]}
     -> appends any new transactions (idempotent by id) -> {"ledger": [txn, ...]}

A txn is the client's BeanTransaction JSON: {id, type, amount, ts, note?, price?}.
Beans transactions (grant / spend / purchase / refund) are immutable, so a write
is idempotent by id and a read returns the union — the balance is the signed sum
of `amount`. The ledger is keyed to the account, so Beans follow the user across
devices. Isolated from the food/weight/profile sync (its own table + endpoint).
"""

import json
import os

from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

TABLE_NAME = os.environ.get("BEANS_TABLE", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)


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


def handler(event, context):
    try:
        token = _bearer(event)
        claims = verify_session_token(token, _get_secret(SESSION_KEY_PARAM))
        user_id = claims.get("sub")
        if not user_id:
            raise ProxyError(401, "Not authenticated.")
        store = _store()

        # Load the account's ledger once (this is also the GET response body).
        ledger = [
            json.loads(i["txn"])
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
