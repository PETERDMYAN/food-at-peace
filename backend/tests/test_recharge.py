import hashlib
import hmac
import json
import time

import pytest

import beans
import common
import recharge
import session

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"
STRIPE_SECRET = "sk_test_x"
WEBHOOK_SECRET = "whsec_test_x"


class FakeStore:
    def __init__(self):
        self.items = {}

    def get(self, user_id, sk):
        return self.items.get((user_id, sk))

    def put(self, item):
        self.items[(item["userId"], item["sk"])] = dict(item)

    def list_for_user(self, user_id):
        return [v for (u, _sk), v in self.items.items() if u == user_id]


@pytest.fixture
def store(monkeypatch):
    fake = FakeStore()
    monkeypatch.setattr(beans, "_store", lambda: fake)  # recharge calls beans._store()
    return fake


@pytest.fixture(autouse=True)
def secrets():
    common._secrets.clear()
    common._secrets[recharge.SESSION_KEY_PARAM] = SESSION_KEY
    common._secrets[recharge.STRIPE_SECRET_PARAM] = STRIPE_SECRET
    common._secrets[recharge.STRIPE_WEBHOOK_SECRET_PARAM] = WEBHOOK_SECRET
    yield
    common._secrets.clear()


@pytest.fixture(autouse=True)
def captured_metrics(monkeypatch):
    """Capture owner-dashboard purchase records (and keep tests off boto3)."""
    calls = []
    monkeypatch.setattr(
        recharge.metrics, "record_event", lambda body, **kw: calls.append(body)
    )
    return calls


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _checkout(body=None, token=None, user_id="apple:u1"):
    if token is None:
        token = _token(user_id)
    headers = {"content-type": "application/json"}
    if token is not False:
        headers["authorization"] = f"Bearer {token}"
    event = {
        "headers": headers,
        "requestContext": {"http": {"method": "POST", "path": "/recharge/checkout"}},
        "body": json.dumps(body or {}),
        "isBase64Encoded": False,
    }
    resp = recharge.handler(event, None)
    return resp["statusCode"], json.loads(resp["body"])


def _sign(payload, secret=WEBHOOK_SECRET, ts=None):
    ts = int(time.time()) if ts is None else ts
    signed = f"{ts}.".encode("utf-8") + payload.encode("utf-8")
    v1 = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return f"t={ts},v1={v1}"


def _completed_event(user_id="apple:u1", product_id="beans_200", sid="cs_1",
                     beans_meta="200", paid=True):
    return {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": sid,
                "payment_status": "paid" if paid else "unpaid",
                "client_reference_id": user_id,
                "metadata": {
                    "userId": user_id,
                    "productId": product_id,
                    "beans": beans_meta,
                },
            }
        },
    }


def _webhook(event_dict, sig=None):
    payload = json.dumps(event_dict)
    headers = {"content-type": "application/json",
               "stripe-signature": _sign(payload) if sig is None else sig}
    event = {
        "headers": headers,
        "requestContext": {"http": {"method": "POST", "path": "/recharge/webhook"}},
        "body": payload,
        "isBase64Encoded": False,
    }
    resp = recharge.handler(event, None)
    return resp["statusCode"], json.loads(resp["body"])


def _balance(store, user_id="apple:u1"):
    return sum(json.loads(i["txn"])["amount"] for i in store.list_for_user(user_id))


# ----------------------------- /recharge/checkout -------------------------- #
def test_checkout_rejects_missing_token(store):
    status, _ = _checkout(body={"productId": "beans_200"}, token=False)
    assert status == 401


def test_checkout_rejects_unknown_product(store):
    status, _ = _checkout(body={"productId": "nope"})
    assert status == 400


def test_checkout_unconfigured_when_no_secret(store, monkeypatch):
    common._secrets.pop(recharge.STRIPE_SECRET_PARAM, None)

    def boom():
        raise RuntimeError("no aws in tests")

    monkeypatch.setattr(common, "_ssm_client", boom)
    status, body = _checkout(body={"productId": "beans_200"})
    assert status == 200
    assert body == {"configured": False}


def test_checkout_returns_stripe_url(store, monkeypatch):
    seen = {}

    def fake_session(secret, product_id, beans_amount, sgd, user_id):
        seen.update(product_id=product_id, beans=beans_amount, sgd=sgd, user=user_id)
        return {"id": "cs_test_1", "url": "https://checkout.stripe.com/c/pay/cs_test_1"}

    monkeypatch.setattr(recharge, "_create_checkout_session", fake_session)
    status, body = _checkout(body={"productId": "beans_200"})
    assert status == 200
    assert body["url"].startswith("https://checkout.stripe.com/")
    assert seen == {"product_id": "beans_200", "beans": 200, "sgd": 3.99, "user": "apple:u1"}


# ----------------------------- /recharge/webhook -------------------------- #
def test_webhook_rejects_bad_signature(store):
    status, _ = _webhook(_completed_event(), sig="t=1,v1=deadbeef")
    assert status == 400
    assert _balance(store) == 0


def test_webhook_rejects_stale_timestamp(store):
    payload = json.dumps(_completed_event())
    stale = _sign(payload, ts=int(time.time()) - 10_000)
    status, _ = _webhook(_completed_event(), sig=stale)
    # signature was computed over a different payload string, so just assert no credit
    assert _balance(store) == 0
    assert status == 400


def test_webhook_credits_beans_once(store, captured_metrics):
    status, body = _webhook(_completed_event(sid="cs_aaa"))
    assert status == 200
    assert body == {"received": True}
    assert _balance(store) == 200
    # Stripe retries the same event -> no double credit, no double revenue.
    _webhook(_completed_event(sid="cs_aaa"))
    assert _balance(store) == 200
    assert len(captured_metrics) == 1
    assert captured_metrics[0] == {"type": "purchase", "beans": 200, "amountCents": 399}


def test_webhook_recomputes_beans_from_product_not_metadata(store):
    # A tampered `beans` metadata must NOT inflate the credit — productId wins.
    _webhook(_completed_event(product_id="beans_25", beans_meta="999999", sid="cs_b"))
    assert _balance(store) == 25


def test_webhook_ignores_unpaid_session(store, captured_metrics):
    status, _ = _webhook(_completed_event(paid=False))
    assert status == 200
    assert _balance(store) == 0
    assert captured_metrics == []


def test_webhook_ignores_other_event_types(store, captured_metrics):
    status, _ = _webhook({"type": "payment_intent.created", "data": {"object": {}}})
    assert status == 200
    assert _balance(store) == 0
    assert captured_metrics == []


def test_webhook_unconfigured_secret_accepts_and_ignores(store, monkeypatch):
    common._secrets.pop(recharge.STRIPE_WEBHOOK_SECRET_PARAM, None)

    def boom():
        raise RuntimeError("no aws in tests")

    monkeypatch.setattr(common, "_ssm_client", boom)
    status, body = _webhook(_completed_event())
    assert status == 200
    assert body == {"received": True, "configured": False}
    assert _balance(store) == 0


def test_verify_signature_unit():
    payload = b'{"hello":"world"}'
    ts = 1_700_000_000
    signed = f"{ts}.".encode("utf-8") + payload
    good = hmac.new(WEBHOOK_SECRET.encode(), signed, hashlib.sha256).hexdigest()
    header = f"t={ts},v1={good}"
    assert recharge._verify_stripe_signature(payload, header, WEBHOOK_SECRET, now=ts)
    # Wrong secret fails.
    assert not recharge._verify_stripe_signature(payload, header, "whsec_other", now=ts)
    # Tampered payload fails.
    assert not recharge._verify_stripe_signature(payload + b"x", header, WEBHOOK_SECRET, now=ts)
    # Stale timestamp fails.
    assert not recharge._verify_stripe_signature(payload, header, WEBHOOK_SECRET, now=ts + 10_000)
