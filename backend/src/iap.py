"""Apple IAP receipt validation + server-side Beans crediting.

POST /iap/validate  (Authorization: Bearer <sessionToken>)
  body {"receipt": "<base64 app receipt>", "productId": "beans_200"}
  -> verify the receipt with Apple (shared secret), then idempotently credit the
     Beans to the account's ledger and return
     {"valid": true, "beans": N, "ledger": [...]}.

Fraud-hardening: Beans for a real purchase are credited only after Apple confirms
the receipt, server-side — a tampered client can't mint Beans this way. If the
shared secret isn't configured yet, returns {"valid": false, "reason":
"unconfigured"} so the client can fall back to its local credit (nothing breaks).
Shares the Beans table + ledger with beans.py (idempotent by id).
"""

import json
import os
import urllib.request
from datetime import datetime, timezone

import beans  # reuse the Beans table store + bearer parsing
from common import ProxyError, _get_secret, _parse_body, _response
from session import verify_session_token

SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)
IAP_SECRET_PARAM = os.environ.get(
    "IAP_SECRET_PARAM", "/food-at-peace/iap-shared-secret"
)

# product id -> (Beans granted, indicative SGD). MUST match the app's
# kBeanProductIds / BeanPricing.packs.
PRODUCTS = {
    "beans_100": (100, 1.99),
    "beans_200": (200, 3.99),
    "beans_300": (300, 5.99),
    "beans_500": (500, 9.48),
    "beans_800": (800, 13.98),
}

_PROD = "https://buy.itunes.apple.com/verifyReceipt"
_SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt"


def _post_apple(url, body):
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={"content-type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:  # noqa: S310 (Apple URL)
        return json.loads(resp.read().decode("utf-8"))


def _verify(receipt, secret):
    """Verify against production, retrying sandbox on 21007 (a sandbox receipt)."""
    body = {
        "receipt-data": receipt,
        "password": secret,
        "exclude-old-transactions": True,
    }
    data = _post_apple(_PROD, body)
    if data.get("status") == 21007:
        data = _post_apple(_SANDBOX, body)
    return data


def handler(event, context):
    try:
        token = beans._bearer(event)
        claims = verify_session_token(token, _get_secret(SESSION_KEY_PARAM))
        user_id = claims.get("sub")
        if not user_id:
            raise ProxyError(401, "Not authenticated.")

        body = _parse_body(event)
        receipt = (body.get("receipt") or "").strip()
        product_id = (body.get("productId") or "").strip()
        if not receipt or product_id not in PRODUCTS:
            raise ProxyError(400, "Missing receipt or unknown product.")

        try:
            secret = _get_secret(IAP_SECRET_PARAM)
        except Exception:  # noqa: BLE001 — secret not provisioned yet
            return _response(200, {"valid": False, "reason": "unconfigured"})

        data = _verify(receipt, secret)
        if data.get("status") != 0:
            return _response(
                200,
                {"valid": False, "reason": "invalid", "status": data.get("status")},
            )

        # Find the in-app line for this product; its transaction id keys the
        # idempotent credit (one credit per Apple transaction, ever).
        entries = (data.get("receipt") or {}).get("in_app") or data.get(
            "latest_receipt_info"
        ) or []
        txid = None
        for e in entries:
            if e.get("product_id") == product_id:
                txid = e.get("transaction_id") or e.get("original_transaction_id")
                break
        if not txid:
            return _response(
                200, {"valid": False, "reason": "product_not_in_receipt"}
            )

        granted, sgd = PRODUCTS[product_id]
        store = beans._store()
        sk = f"iap-{txid}"
        ledger = [
            json.loads(i["txn"])
            for i in store.list_for_user(user_id)
            if i.get("txn")
        ]
        if not any(t.get("id") == sk for t in ledger):
            txn = {
                "id": sk,
                "type": "purchase",
                "amount": granted,
                "ts": datetime.now(timezone.utc).isoformat(),
                "price": sgd,
            }
            store.put({"userId": user_id, "sk": sk, "txn": json.dumps(txn)})
            ledger.append(txn)

        return _response(200, {"valid": True, "beans": granted, "ledger": ledger})
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
