import json

import pytest

import common
import session
import sync

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


class FakeStore:
    """In-memory stand-in for the DynamoDB-backed store."""

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
    monkeypatch.setattr(sync, "_store", lambda: fake)
    return fake


@pytest.fixture(autouse=True)
def stub_session_key():
    common._secrets.clear()
    common._secrets[sync.SESSION_KEY_PARAM] = SESSION_KEY
    yield
    common._secrets.clear()


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _event(body, token=None, user_id="apple:u1"):
    headers = {"content-type": "application/json"}
    if token is None:
        token = _token(user_id)
    if token is not False:  # pass token=False to omit the header
        headers["authorization"] = f"Bearer {token}"
    return {"headers": headers, "body": json.dumps(body), "isBase64Encoded": False}


def _food(rid, updated_at, deleted=False, name="Toast"):
    return {
        "id": rid,
        "updatedAt": updated_at,
        "deleted": deleted,
        "data": {"id": rid, "name": name, "calories": 120},
    }


def _sync(body, **kw):
    resp = sync.handler(_event(body, **kw), None)
    return resp["statusCode"], json.loads(resp["body"])


# --- auth --------------------------------------------------------------------


def test_rejects_missing_token(store):
    status, _ = _sync({"since": 0, "changes": {}}, token=False)
    assert status == 401


def test_rejects_bad_token(store):
    status, _ = _sync({"since": 0, "changes": {}}, token="not-a-real-token")
    assert status == 401


# --- push + pull -------------------------------------------------------------


def test_push_then_pull_roundtrip(store):
    status, _ = _sync({"since": 0, "changes": {"food": [_food("a", 100)]}})
    assert status == 200
    status, out = _sync({"since": 0, "changes": {}})
    assert status == 200
    assert [r["id"] for r in out["changes"]["food"]] == ["a"]
    assert out["changes"]["food"][0]["data"]["name"] == "Toast"


def test_lww_keeps_stored_when_incoming_older(store):
    _sync({"since": 0, "changes": {"food": [_food("a", 200, name="New")]}})
    _sync({"since": 0, "changes": {"food": [_food("a", 100, name="Old")]}})
    _, out = _sync({"since": 0, "changes": {}})
    assert out["changes"]["food"][0]["data"]["name"] == "New"
    assert out["changes"]["food"][0]["updatedAt"] == 200


def test_lww_applies_newer(store):
    _sync({"since": 0, "changes": {"food": [_food("a", 100, name="Old")]}})
    _sync({"since": 0, "changes": {"food": [_food("a", 200, name="New")]}})
    _, out = _sync({"since": 0, "changes": {}})
    assert out["changes"]["food"][0]["data"]["name"] == "New"


def test_delta_filters_by_since(store):
    _sync({"since": 0, "changes": {"food": [_food("a", 100), _food("b", 300)]}})
    _, out = _sync({"since": 200, "changes": {}})
    assert [r["id"] for r in out["changes"]["food"]] == ["b"]


def test_tombstone_propagates(store):
    _sync({"since": 0, "changes": {"food": [_food("a", 100)]}})
    _sync({"since": 0, "changes": {"food": [_food("a", 200, deleted=True)]}})
    _, out = _sync({"since": 0, "changes": {}})
    rec = out["changes"]["food"][0]
    assert rec["deleted"] is True
    assert rec["updatedAt"] == 200


def test_profile_singleton(store):
    prof = {"updatedAt": 50, "data": {"goal": "lose", "weightKg": 75}}
    _sync({"since": 0, "changes": {"profile": prof}})
    _, out = _sync({"since": 0, "changes": {}})
    assert out["changes"]["profile"]["data"]["goal"] == "lose"
    # A second profile push overwrites the singleton (newer wins).
    _sync({"since": 0, "changes": {"profile": {"updatedAt": 60, "data": {"goal": "gain"}}}})
    _, out = _sync({"since": 0, "changes": {}})
    assert out["changes"]["profile"]["data"]["goal"] == "gain"


def test_user_isolation(store):
    _sync({"since": 0, "changes": {"food": [_food("a", 100)]}}, user_id="apple:u1")
    status, out = _sync({"since": 0, "changes": {}}, user_id="apple:u2")
    assert status == 200
    assert out["changes"]["food"] == []


def test_weight_and_food_separate(store):
    _sync(
        {
            "since": 0,
            "changes": {
                "food": [_food("f1", 100)],
                "weight": [{"id": "w1", "updatedAt": 100, "data": {"kg": 75}}],
            },
        }
    )
    _, out = _sync({"since": 0, "changes": {}})
    assert [r["id"] for r in out["changes"]["food"]] == ["f1"]
    assert [r["id"] for r in out["changes"]["weight"]] == ["w1"]
    assert out["changes"]["weight"][0]["data"]["kg"] == 75
