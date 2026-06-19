import json

import pytest

import common
import mealphotos
import session

SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


class FakeS3:
    """Records calls and returns deterministic fake presigned URLs."""

    def __init__(self):
        self.deleted = []
        self.signed = []

    def generate_presigned_url(self, op, Params, ExpiresIn):  # noqa: N803
        self.signed.append((op, Params["Key"], ExpiresIn))
        return f"https://s3.example/{op}/{Params['Key']}?exp={ExpiresIn}"

    def delete_object(self, Bucket, Key):  # noqa: N803
        self.deleted.append(Key)


@pytest.fixture
def s3(monkeypatch):
    fake = FakeS3()
    monkeypatch.setattr(mealphotos, "_s3c", lambda: fake)
    monkeypatch.setattr(mealphotos, "MEAL_PHOTOS_BUCKET", "meal-bucket")
    return fake


@pytest.fixture(autouse=True)
def stub_session_key():
    common._secrets.clear()
    common._secrets[mealphotos.SESSION_KEY_PARAM] = SESSION_KEY
    yield
    common._secrets.clear()


def _token(user_id="apple:u1"):
    return session.mint_session_token(user_id, SESSION_KEY, 3600)


def _event(path, body, token=None, user_id="apple:u1"):
    headers = {"content-type": "application/json"}
    if token is None:
        token = _token(user_id)
    if token is not False:
        headers["authorization"] = f"Bearer {token}"
    return {
        "headers": headers,
        "requestContext": {"http": {"method": "POST", "path": f"/photo/{path}"}},
        "body": json.dumps(body),
        "isBase64Encoded": False,
    }


def _call(path, body, **kw):
    resp = mealphotos.handler(_event(path, body, **kw), None)
    return resp["statusCode"], json.loads(resp["body"])


# --- auth --------------------------------------------------------------------


def test_rejects_missing_token(s3):
    status, _ = _call("put-url", {"entryId": "1"}, token=False)
    assert status == 401


def test_rejects_bad_token(s3):
    status, _ = _call("put-url", {"entryId": "1"}, token="nope")
    assert status == 401


# --- presigned PUT/GET/delete, scoped to the user ----------------------------


def test_put_url_signs_under_the_users_own_prefix(s3):
    status, out = _call("put-url", {"entryId": "12345", "mediaType": "image/jpeg"})
    assert status == 200
    assert out["url"].startswith("https://s3.example/put_object/")
    op, key, _ttl = s3.signed[0]
    assert op == "put_object"
    assert key == "meal/apple:u1/12345.jpg"  # scoped to the verified uid


def test_get_urls_batches_and_skips_blanks(s3):
    status, out = _call("get-urls", {"entryIds": ["a1", "b2", ""]})
    assert status == 200
    assert set(out["urls"]) == {"a1", "b2"}  # blank id dropped
    assert out["urls"]["a1"].startswith("https://s3.example/get_object/")


def test_delete_removes_the_users_object(s3):
    status, out = _call("delete", {"entryId": "z9"})
    assert status == 200 and out["ok"] is True
    assert s3.deleted == ["meal/apple:u1/z9.jpg"]


def test_entry_id_cannot_escape_the_user_prefix(s3):
    # A traversal attempt is sanitized to plain chars — never breaks out of meal/<uid>/.
    _call("put-url", {"entryId": "../../etc/passwd"})
    _op, key, _ttl = s3.signed[0]
    assert key.startswith("meal/apple:u1/")
    assert ".." not in key and "/etc/" not in key


def test_two_users_get_isolated_keys(s3):
    _call("put-url", {"entryId": "777"}, user_id="apple:alice")
    _call("put-url", {"entryId": "777"}, user_id="apple:bob")
    keys = [k for _op, k, _ttl in s3.signed]
    assert keys == ["meal/apple:alice/777.jpg", "meal/apple:bob/777.jpg"]
