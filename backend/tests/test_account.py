import json
import time

import pytest

import account
import common
import session
import sync as sync_mod

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


class FakeStore:
    """In-memory stand-in shared by the account- and sync-handler stores."""

    def __init__(self):
        self.items = {}

    def seed(self, user_id, sk):
        self.items[(user_id, sk)] = {"userId": user_id, "sk": sk, "updatedAt": 1}

    def get(self, user_id, sk):
        return self.items.get((user_id, sk))

    def put(self, item):
        self.items[(item["userId"], item["sk"])] = dict(item)

    def keys_for_user(self, user_id):
        return [sk for (u, sk) in self.items if u == user_id]

    def delete_many(self, user_id, sks):
        for sk in sks:
            self.items.pop((user_id, sk), None)

    def list_for_user(self, user_id):
        return [v for (u, _sk), v in self.items.items() if u == user_id]


@pytest.fixture
def store(monkeypatch):
    fake = FakeStore()
    monkeypatch.setattr(account, "_store", lambda: fake)
    monkeypatch.setattr(sync_mod, "_store", lambda: fake)
    return fake


@pytest.fixture(autouse=True)
def stub_session_key():
    common._secrets.clear()
    common._secrets[account.SESSION_KEY_PARAM] = SESSION_KEY
    yield
    common._secrets.clear()


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _event(token=None, user_id="apple:u1"):
    headers = {"content-type": "application/json"}
    if token is None:
        token = _token(user_id)
    if token is not False:  # pass token=False to omit the header
        headers["authorization"] = f"Bearer {token}"
    return {"headers": headers, "body": "{}", "isBase64Encoded": False}


def _delete(**kw):
    resp = account.handler(_event(**kw), None)
    return resp["statusCode"], json.loads(resp["body"])


# --- auth --------------------------------------------------------------------


def test_rejects_missing_token(store):
    status, _ = _delete(token=False)
    assert status == 401


def test_rejects_bad_token(store):
    status, _ = _delete(token="not-a-real-token")
    assert status == 401


# --- deletion ----------------------------------------------------------------


def test_deletes_all_rows_for_the_user_only(store):
    store.seed("apple:u1", "food#a")
    store.seed("apple:u1", "weight#b")
    store.seed("apple:u1", "profile")
    store.seed("apple:u2", "food#other")

    status, body = _delete(user_id="apple:u1")

    assert status == 200
    assert body == {"deleted": 3}
    # The user's data rows are gone; the other user's row is untouched. What
    # remains for u1 is the revocation marker.
    assert store.keys_for_user("apple:u1") == [account.DELETED_MARKER_SK]
    assert store.keys_for_user("apple:u2") == ["food#other"]


def test_idempotent_on_empty_account(store):
    status, body = _delete(user_id="apple:u1")
    assert status == 200
    assert body == {"deleted": 0}


# --- token revocation via the deletion marker --------------------------------


def test_deletion_writes_a_revocation_marker(store):
    _delete(user_id="apple:u1")
    marker = store.get("apple:u1", account.DELETED_MARKER_SK)
    assert marker is not None
    assert marker["minIat"] == pytest.approx(time.time(), abs=5)


def test_pre_deletion_token_is_rejected_after_deletion(store, monkeypatch):
    old_token = _token()  # minted "now"
    # Deletion happens 100s later → marker.minIat is in this token's future.
    real_time = time.time
    monkeypatch.setattr(time, "time", lambda: real_time() + 100)
    status, _ = _delete(user_id="apple:u1")
    assert status == 200
    monkeypatch.setattr(time, "time", real_time)

    # The old token can no longer delete (or, via the same check in sync.py,
    # re-upload) anything.
    status, body = _delete(token=old_token)
    assert status == 401
    assert "sign in" in body["error"]["message"].lower()


def test_fresh_token_after_deletion_is_accepted(store):
    _delete(user_id="apple:u1")
    # A re-sign-in mints a newer token (iat ≥ marker.minIat) → works again.
    store.seed("apple:u1", "food#new")
    status, body = _delete(user_id="apple:u1")
    assert status == 200
    assert body == {"deleted": 1}


def test_sync_after_deletion_with_fresh_token_succeeds_and_hides_marker(store):
    """Regression: the marker row (no real updatedAt) must not 500 /sync or
    leak into the delta a re-signed-in client pulls."""
    store.seed("apple:u1", "food#a")
    _delete(user_id="apple:u1")

    event = _event(user_id="apple:u1")  # fresh token, iat ≥ marker.minIat
    event["body"] = json.dumps({"since": 0, "changes": {}})
    resp = sync_mod.handler(event, None)
    body = json.loads(resp["body"])

    assert resp["statusCode"] == 200
    assert body["changes"] == {"food": [], "weight": [], "profile": None}


def test_sync_rejects_pre_deletion_token(store, monkeypatch):
    old_token = _token()
    real_time = time.time
    monkeypatch.setattr(time, "time", lambda: real_time() + 100)
    _delete(user_id="apple:u1")
    monkeypatch.setattr(time, "time", real_time)

    event = _event(token=old_token)
    event["body"] = json.dumps({"since": 0, "changes": {}})
    resp = sync_mod.handler(event, None)
    assert resp["statusCode"] == 401


def test_marker_survives_repeat_deletion_and_check_helper():
    # The helper itself: no marker → pass; older iat → 401; newer iat → pass.
    account.check_token_not_revoked({"iat": 100}, None)
    account.check_token_not_revoked({"iat": 100}, {"minIat": 50})
    with pytest.raises(common.ProxyError):
        account.check_token_not_revoked({"iat": 100}, {"minIat": 200})


# --- Beans ledger cleanup (isolated table) -----------------------------------


@pytest.fixture
def beans_store(monkeypatch):
    fake = FakeStore()
    monkeypatch.setattr(account, "_beans_store", lambda: fake)
    return fake


def test_deletion_also_clears_the_beans_ledger(store, beans_store):
    store.seed("apple:u1", "food#a")
    beans_store.put({"userId": "apple:u1", "sk": "grant_1", "txn": "{}"})
    beans_store.put({"userId": "apple:u1", "sk": "buy_1", "txn": "{}"})
    beans_store.put({"userId": "apple:u2", "sk": "buy_other", "txn": "{}"})

    status, body = _delete(user_id="apple:u1")

    assert status == 200
    assert body == {"deleted": 1}  # the sync row; beans rows aren't counted
    assert beans_store.keys_for_user("apple:u1") == []  # user's beans gone
    assert beans_store.keys_for_user("apple:u2") == ["buy_other"]  # others' kept


def test_deletion_without_a_beans_table_is_a_noop(store):
    # No beans_store fixture → account._beans_store() returns None (BEANS_TABLE
    # unset). Deletion must still succeed (the clear is best-effort/optional).
    store.seed("apple:u1", "profile")
    status, body = _delete(user_id="apple:u1")
    assert status == 200
    assert body == {"deleted": 1}
