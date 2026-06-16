import json

import pytest

import beans
import common
import session

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


class FakeStore:
    """In-memory stand-in for the Beans DynamoDB table."""

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
    monkeypatch.setattr(beans, "_store", lambda: fake)
    return fake


@pytest.fixture(autouse=True)
def stub_session_key():
    common._secrets.clear()
    common._secrets[beans.SESSION_KEY_PARAM] = SESSION_KEY
    yield
    common._secrets.clear()


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _event(method, body=None, token=None, user_id="apple:u1"):
    headers = {"content-type": "application/json"}
    if token is None:
        token = _token(user_id)
    if token is not False:  # pass token=False to omit the header
        headers["authorization"] = f"Bearer {token}"
    return {
        "headers": headers,
        "requestContext": {"http": {"method": method}},
        "body": json.dumps(body or {}),
        "isBase64Encoded": False,
    }


def _call(method, **kw):
    resp = beans.handler(_event(method, **kw), None)
    return resp["statusCode"], json.loads(resp["body"])


def _grant(tid="grant_1", amount=100):
    return {"id": tid, "type": "signupGrant", "amount": amount, "ts": "2026-06-16T09:00:00"}


def _purchase(tid, amount, price=1.99):
    return {"id": tid, "type": "purchase", "amount": amount, "ts": "2026-06-16T10:00:00", "price": price}


def _balance(ledger):
    return sum(t["amount"] for t in ledger)


# --- auth --------------------------------------------------------------------


def test_rejects_missing_token(store):
    status, _ = _call("GET", token=False)
    assert status == 401


def test_rejects_bad_token(store):
    status, _ = _call("GET", token="not-a-real-token")
    assert status == 401


# --- get / post --------------------------------------------------------------


def test_get_empty_ledger(store):
    status, body = _call("GET")
    assert status == 200
    assert body == {"ledger": []}


def test_post_appends_then_get_returns_them(store):
    status, body = _call("POST", body={"txns": [_grant(), _purchase("buy_1", 200)]})
    assert status == 200
    assert _balance(body["ledger"]) == 300
    _, body2 = _call("GET")
    assert _balance(body2["ledger"]) == 300


def test_post_is_idempotent_by_id(store):
    _call("POST", body={"txns": [_purchase("buy_1", 200)]})
    status, body = _call("POST", body={"txns": [_purchase("buy_1", 200)]})
    assert [t["id"] for t in body["ledger"]].count("buy_1") == 1
    assert _balance(body["ledger"]) == 200


def test_only_one_signup_grant_per_account(store):
    # Two devices each push their own local 100-bean grant (different ids).
    _call("POST", body={"txns": [_grant("grant_A", 100)]})
    status, body = _call("POST", body={"txns": [_grant("grant_B", 100)]})
    grants = [t for t in body["ledger"] if t["type"] == "signupGrant"]
    assert len(grants) == 1
    assert grants[0]["id"] == "grant_A"  # the first one is kept
    assert _balance(body["ledger"]) == 100  # not doubled to 200


def test_grant_guard_does_not_block_purchases_in_the_same_batch(store):
    status, body = _call(
        "POST",
        body={"txns": [_grant("grant_A", 100), _purchase("buy_1", 80, 1.59), _grant("grant_B", 100)]},
    )
    assert status == 200
    assert _balance(body["ledger"]) == 180  # 100 grant + 80 purchase; 2nd grant dropped


def test_ledger_is_scoped_to_the_user(store):
    _call("POST", body={"txns": [_purchase("buy_1", 200)]}, user_id="apple:u1")
    status, body = _call("GET", user_id="apple:u2")
    assert body["ledger"] == []
