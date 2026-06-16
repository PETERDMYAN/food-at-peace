import json

import pytest

import beans
import common
import iap
import session

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


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
    monkeypatch.setattr(beans, "_store", lambda: fake)  # iap calls beans._store()
    return fake


@pytest.fixture(autouse=True)
def secrets():
    common._secrets.clear()
    common._secrets[iap.SESSION_KEY_PARAM] = SESSION_KEY
    common._secrets[iap.IAP_SECRET_PARAM] = "shared-secret"
    yield
    common._secrets.clear()


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _call(body=None, token=None, user_id="apple:u1"):
    if token is None:
        token = _token(user_id)
    headers = {"content-type": "application/json"}
    if token is not False:
        headers["authorization"] = f"Bearer {token}"
    event = {
        "headers": headers,
        "requestContext": {"http": {"method": "POST"}},
        "body": json.dumps(body or {}),
        "isBase64Encoded": False,
    }
    resp = iap.handler(event, None)
    return resp["statusCode"], json.loads(resp["body"])


def _apple_ok(product_id="beans_200", txid="tx-1"):
    return {
        "status": 0,
        "receipt": {"in_app": [{"product_id": product_id, "transaction_id": txid}]},
    }


def test_rejects_missing_token(store):
    status, _ = _call(body={"receipt": "r", "productId": "beans_200"}, token=False)
    assert status == 401


def test_rejects_unknown_product(store):
    status, _ = _call(body={"receipt": "r", "productId": "nope"})
    assert status == 400


def test_unconfigured_when_no_secret(store, monkeypatch):
    common._secrets.pop(iap.IAP_SECRET_PARAM, None)

    def boom():
        raise RuntimeError("no aws in tests")

    monkeypatch.setattr(common, "_ssm_client", boom)
    status, body = _call(body={"receipt": "r", "productId": "beans_200"})
    assert status == 200
    assert body == {"valid": False, "reason": "unconfigured"}


def test_invalid_receipt(store, monkeypatch):
    monkeypatch.setattr(iap, "_verify", lambda r, s: {"status": 21002})
    status, body = _call(body={"receipt": "r", "productId": "beans_200"})
    assert status == 200
    assert body["valid"] is False
    assert body["reason"] == "invalid"
    assert body["status"] == 21002


def test_valid_receipt_credits_idempotently(store, monkeypatch):
    monkeypatch.setattr(iap, "_verify", lambda r, s: _apple_ok("beans_200", "tx-1"))
    status, body = _call(body={"receipt": "r", "productId": "beans_200"})
    assert status == 200
    assert body["valid"] is True
    assert body["beans"] == 200
    assert sum(t["amount"] for t in body["ledger"]) == 200
    # Re-submitting the same Apple transaction must not double-credit.
    _, body2 = _call(body={"receipt": "r", "productId": "beans_200"})
    assert sum(t["amount"] for t in body2["ledger"]) == 200
    assert [t["id"] for t in body2["ledger"]].count("iap-tx-1") == 1


def test_beans_25_credits_25(store, monkeypatch):
    monkeypatch.setattr(iap, "_verify", lambda r, s: _apple_ok("beans_25", "tx-25"))
    status, body = _call(body={"receipt": "r", "productId": "beans_25"})
    assert status == 200
    assert body["valid"] is True
    assert body["beans"] == 25


def test_rejects_product_not_in_receipt(store, monkeypatch):
    monkeypatch.setattr(iap, "_verify", lambda r, s: _apple_ok("beans_800", "tx-9"))
    status, body = _call(body={"receipt": "r", "productId": "beans_200"})
    assert status == 200
    assert body["valid"] is False
    assert body["reason"] == "product_not_in_receipt"
