"""Web Beans recharge via Stripe Checkout (no Apple IAP, no app required).

Two routes, both on this one Lambda:

  POST /recharge/checkout   (Authorization: Bearer <sessionToken>)
      body {"productId": "beans_200"}
      -> create a Stripe Checkout Session for that pack and return {"url": ...}.
         The browser redirects there; Stripe hosts the card form (PCI stays with
         Stripe — no card data ever touches us).

  POST /recharge/webhook    (Stripe-Signature header; NO bearer)
      <- Stripe calls this after payment. We verify the signature, and on
         `checkout.session.completed` (paid) credit the Beans server-side into the
         same BeansTable ledger beans.py / iap.py use.

Fraud-hardening (same shape as iap.py): the webhook is the ONLY thing that mints
Beans for a web purchase, and it does so only after verifying Stripe's HMAC
signature — a forged request can't credit Beans. The credit is idempotent by
Stripe session id, and the Beans amount is recomputed from `productId` on our
side (never trusted from client-supplied metadata). If the Stripe secrets aren't
provisioned yet, /checkout returns {"configured": false} (200) so the web page
can degrade gracefully, exactly like iap.py's "unconfigured".

Pure standard library (urllib + hmac/hashlib) — no `stripe` SDK, so nothing is
added to the shared src/requirements.txt that every Lambda bundles.
"""

import hashlib
import hmac
import json
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import beans  # reuse the Beans table store + bearer parsing
import metrics  # owner-dashboard counters (beans sold + revenue)
from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)
STRIPE_SECRET_PARAM = os.environ.get(
    "STRIPE_SECRET_PARAM", "/food-at-peace/stripe-secret-key"
)
STRIPE_WEBHOOK_SECRET_PARAM = os.environ.get(
    "STRIPE_WEBHOOK_SECRET_PARAM", "/food-at-peace/stripe-webhook-secret"
)

# Where Stripe sends the customer back. The web recharge page lives here.
SITE_URL = os.environ.get("RECHARGE_SITE_URL", "https://foodatpeace.app/recharge")

# product id -> (Beans granted, SGD price). MUST match the app's kBeanProductIds /
# BeanPricing.packs and iap.PRODUCTS. The web flow only sells the public packs.
PRODUCTS = {
    "beans_25": (25, 0.48),
    "beans_100": (100, 1.99),
    "beans_200": (200, 3.99),
    "beans_300": (300, 5.99),
    "beans_500": (500, 9.48),
    "beans_800": (800, 13.98),
}

_STRIPE_API = "https://api.stripe.com/v1/checkout/sessions"
# Reject webhook events whose timestamp is older than this (replay protection).
_WEBHOOK_TOLERANCE_S = 300


def _method(event):
    http = (event.get("requestContext") or {}).get("http") or {}
    return (http.get("method") or event.get("httpMethod") or "GET").upper()


def _path(event):
    http = (event.get("requestContext") or {}).get("http") or {}
    return http.get("path") or event.get("rawPath") or event.get("path") or ""


def _raw_body(event):
    """The exact bytes Stripe signed (decode base64 if API Gateway encoded it)."""
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        import base64

        return base64.b64decode(raw)
    return raw.encode("utf-8")


# --------------------------------------------------------------------------- #
# Stripe REST (hand-rolled — see module docstring)                            #
# --------------------------------------------------------------------------- #
def _create_checkout_session(secret, product_id, beans_amount, sgd, user_id):
    """Create a Stripe Checkout Session and return its hosted-page URL."""
    fields = {
        "mode": "payment",
        "success_url": f"{SITE_URL}?status=success&session_id={{CHECKOUT_SESSION_ID}}",
        "cancel_url": f"{SITE_URL}?status=cancel",
        "client_reference_id": user_id,
        "line_items[0][quantity]": "1",
        "line_items[0][price_data][currency]": "sgd",
        "line_items[0][price_data][unit_amount]": str(round(sgd * 100)),
        "line_items[0][price_data][product_data][name]": f"{beans_amount} beans — Food at Peace",
        # Echoed back verbatim on the webhook event. We still recompute Beans from
        # productId server-side, so tampering with these can't inflate a credit.
        "metadata[userId]": user_id,
        "metadata[productId]": product_id,
        "metadata[beans]": str(beans_amount),
    }
    data = urllib.parse.urlencode(fields).encode("utf-8")
    req = urllib.request.Request(
        _STRIPE_API,
        data=data,
        headers={
            "authorization": f"Bearer {secret}",
            "content-type": "application/x-www-form-urlencoded",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:  # noqa: S310 (Stripe URL)
        return json.loads(resp.read().decode("utf-8"))


def _verify_stripe_signature(payload_bytes, sig_header, secret, now=None):
    """True if `sig_header` is a valid Stripe signature over `payload_bytes`.

    Header form: ``t=<ts>,v1=<hex>[,v1=<hex>...]``. We HMAC-SHA256
    ``"<t>.<payload>"`` with the endpoint secret and constant-time compare against
    each v1, and reject stale timestamps (replay protection).
    """
    if not sig_header or not secret:
        return False
    parts = {}
    v1 = []
    for item in sig_header.split(","):
        key, _, value = item.partition("=")
        key, value = key.strip(), value.strip()
        if key == "v1":
            v1.append(value)
        elif key:
            parts[key] = value
    ts = parts.get("t")
    if not ts or not v1:
        return False
    try:
        ts_int = int(ts)
    except ValueError:
        return False
    now = int(time.time()) if now is None else int(now)
    if abs(now - ts_int) > _WEBHOOK_TOLERANCE_S:
        return False
    signed = f"{ts}.".encode("utf-8") + payload_bytes
    expected = hmac.new(
        secret.encode("utf-8"), signed, hashlib.sha256
    ).hexdigest()
    return any(hmac.compare_digest(expected, candidate) for candidate in v1)


# --------------------------------------------------------------------------- #
# Crediting (shared with beans.py / iap.py: same table, idempotent by id)     #
# --------------------------------------------------------------------------- #
def _credit(user_id, product_id, sk):
    """Append a `purchase` txn for this product, idempotent on `sk`."""
    granted, sgd = PRODUCTS[product_id]
    store = beans._store()
    ledger = [
        json.loads(i["txn"]) for i in store.list_for_user(user_id) if i.get("txn")
    ]
    if any(t.get("id") == sk for t in ledger):
        return granted  # already credited (Stripe retried the webhook)
    txn = {
        "id": sk,
        "type": "purchase",
        "amount": granted,
        "ts": datetime.now(timezone.utc).isoformat(),
        "price": sgd,
    }
    store.put({"userId": user_id, "sk": sk, "txn": json.dumps(txn)})
    # Owner-dashboard revenue + beans-sold, recorded once per Stripe session (inside
    # the idempotency guard). Best-effort: a metrics hiccup must never fail a paid
    # purchase.
    try:
        metrics.record_event(
            {"type": "purchase", "beans": granted, "amountCents": round(sgd * 100)}
        )
    except Exception:  # noqa: BLE001 — revenue stat is non-critical
        pass
    return granted


# --------------------------------------------------------------------------- #
# Route handlers                                                              #
# --------------------------------------------------------------------------- #
def _handle_checkout(event):
    token = beans._bearer(event)
    claims = verify_session_token(token, _get_secret(SESSION_KEY_PARAM))
    user_id = claims.get("sub")
    if not user_id:
        raise ProxyError(401, "Not authenticated.")

    body = _parse_body(event)
    product_id = (body.get("productId") or "").strip()
    if product_id not in PRODUCTS:
        raise ProxyError(400, "Unknown product.")

    try:
        secret = _get_secret(STRIPE_SECRET_PARAM)
    except Exception:  # noqa: BLE001 — secret not provisioned yet
        return _response(200, {"configured": False})

    granted, sgd = PRODUCTS[product_id]
    session = _create_checkout_session(secret, product_id, granted, sgd, user_id)
    url = session.get("url")
    if not url:
        raise ProxyError(502, "Could not start checkout.")
    return _response(200, {"url": url})


def _handle_webhook(event):
    # No bearer here — Stripe authenticates via the signature instead.
    try:
        secret = _get_secret(STRIPE_WEBHOOK_SECRET_PARAM)
    except Exception:  # noqa: BLE001 — secret not provisioned yet
        # Nothing to verify against; accept-and-ignore so Stripe stops retrying.
        return _response(200, {"received": True, "configured": False})

    payload = _raw_body(event)
    sig = _header(event, "stripe-signature")
    if not _verify_stripe_signature(payload, sig, secret):
        raise ProxyError(400, "Bad signature.")

    try:
        evt = json.loads(payload.decode("utf-8"))
    except (ValueError, TypeError):
        raise ProxyError(400, "Invalid payload.")

    if evt.get("type") == "checkout.session.completed":
        obj = (evt.get("data") or {}).get("object") or {}
        # Only credit a genuinely paid session.
        if obj.get("payment_status") == "paid":
            meta = obj.get("metadata") or {}
            user_id = meta.get("userId") or obj.get("client_reference_id")
            product_id = meta.get("productId")
            session_id = obj.get("id")
            if user_id and product_id in PRODUCTS and session_id:
                _credit(user_id, product_id, f"stripe-{session_id}")

    # Always 200 for a verified event (handled or ignored) so Stripe doesn't retry.
    return _response(200, {"received": True})


def handler(event, context):
    try:
        if _method(event) != "POST":
            raise ProxyError(405, "Method not allowed.")
        if _path(event).endswith("/webhook"):
            return _handle_webhook(event)
        return _handle_checkout(event)
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
