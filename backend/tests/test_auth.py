import hashlib
import json
import time

import jwt  # test-only: used to FORGE Apple-style RS256 tokens that jwtlite verifies
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

import auth
import common
import session

CLIENT_ID = "com.foodatpeace.foodAtPeace"
SESSION_KEY = "test-session-signing-key-padding-0123456789ab"


@pytest.fixture
def rsa_key():
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(autouse=True)
def stub_config(monkeypatch):
    """Point auth at a test bundle id + stub the session signing key so no
    AWS/SSM call is ever made."""
    monkeypatch.setattr(auth, "APPLE_CLIENT_ID", CLIENT_ID)
    common._secrets.clear()
    common._secrets[auth.SESSION_KEY_PARAM] = SESSION_KEY
    yield
    common._secrets.clear()


@pytest.fixture(autouse=True)
def stub_jwks(monkeypatch, rsa_key):
    """Serve our local public key for any kid, so verification runs offline
    against a token we sign in the test (no fetch to Apple)."""
    nums = rsa_key.public_key().public_numbers()
    monkeypatch.setattr(auth, "_apple_key_for_kid", lambda kid: (nums.n, nums.e))


def _apple_token(rsa_key, **overrides):
    now = int(time.time())
    claims = {
        "iss": auth.APPLE_ISSUER,
        "aud": CLIENT_ID,
        "sub": "000123.abc.def",
        "iat": now,
        "exp": now + 600,
        "email": "user@example.com",
    }
    claims.update(overrides)
    return jwt.encode(claims, rsa_key, algorithm="RS256", headers={"kid": "k1"})


def _event(body):
    return {
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
        "isBase64Encoded": False,
    }


# --- Apple token verification ------------------------------------------------


def test_verify_happy_path(rsa_key):
    claims = auth.verify_apple_identity_token(_apple_token(rsa_key))
    assert claims["sub"] == "000123.abc.def"
    assert claims["email"] == "user@example.com"


def test_verify_rejects_wrong_audience(rsa_key):
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(_apple_token(rsa_key, aud="com.evil.app"))
    assert exc.value.status == 401


def test_verify_accepts_any_of_multiple_client_ids(rsa_key, monkeypatch):
    # The v2 stack accepts both the prod bundle id and the ".dev" build's id.
    monkeypatch.setattr(
        auth,
        "APPLE_CLIENT_ID",
        "com.foodatpeace.foodAtPeace,com.foodatpeace.foodAtPeace.dev",
    )
    dev = auth.verify_apple_identity_token(
        _apple_token(rsa_key, aud="com.foodatpeace.foodAtPeace.dev")
    )
    assert dev["sub"] == "000123.abc.def"
    prod = auth.verify_apple_identity_token(_apple_token(rsa_key, aud=CLIENT_ID))
    assert prod["sub"] == "000123.abc.def"
    with pytest.raises(common.ProxyError):
        auth.verify_apple_identity_token(_apple_token(rsa_key, aud="com.evil.app"))


def test_verify_rejects_wrong_issuer(rsa_key):
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(
            _apple_token(rsa_key, iss="https://evil.example")
        )
    assert exc.value.status == 401


def test_verify_rejects_expired(rsa_key):
    now = int(time.time())
    token = _apple_token(rsa_key, iat=now - 1200, exp=now - 600)
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(token)
    assert exc.value.status == 401


def test_verify_rejects_bad_signature(rsa_key):
    # Sign with a different key than the JWKS (stubbed to rsa_key) serves.
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(_apple_token(other))
    assert exc.value.status == 401


def test_verify_rejects_alg_confusion(rsa_key):
    # A token that claims HS256 must not be accepted by the RS256 path.
    now = int(time.time())
    forged = jwt.encode(
        {"iss": auth.APPLE_ISSUER, "aud": CLIENT_ID, "sub": "x", "exp": now + 600},
        "public-ish-string",
        algorithm="HS256",
        headers={"kid": "k1"},
    )
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(forged)
    assert exc.value.status == 401


def test_verify_nonce_match(rsa_key):
    raw = "random-nonce-123"
    token = _apple_token(rsa_key, nonce=hashlib.sha256(raw.encode()).hexdigest())
    claims = auth.verify_apple_identity_token(token, raw_nonce=raw)
    assert claims["sub"] == "000123.abc.def"


def test_verify_nonce_mismatch(rsa_key):
    token = _apple_token(
        rsa_key, nonce=hashlib.sha256(b"a-different-nonce").hexdigest()
    )
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(token, raw_nonce="random-nonce-123")
    assert exc.value.status == 401


def test_verify_jwks_failure_is_502(rsa_key, monkeypatch):
    def boom(kid):
        raise RuntimeError("network down")

    monkeypatch.setattr(auth, "_apple_key_for_kid", boom)
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(_apple_token(rsa_key))
    assert exc.value.status == 502


def test_verify_unconfigured_audience_is_500(rsa_key, monkeypatch):
    monkeypatch.setattr(auth, "APPLE_CLIENT_ID", "")
    with pytest.raises(common.ProxyError) as exc:
        auth.verify_apple_identity_token(_apple_token(rsa_key))
    assert exc.value.status == 500


# --- handler -----------------------------------------------------------------


def test_handler_happy_path(rsa_key):
    resp = auth.handler(_event({"identityToken": _apple_token(rsa_key)}), None)
    assert resp["statusCode"] == 200
    out = json.loads(resp["body"])
    assert out["userId"] == "apple:000123.abc.def"
    assert out["email"] == "user@example.com"
    # The returned session token verifies against the (stubbed) signing key.
    claims = session.verify_session_token(out["sessionToken"], SESSION_KEY)
    assert claims["sub"] == "apple:000123.abc.def"


def test_handler_missing_token():
    resp = auth.handler(_event({}), None)
    assert resp["statusCode"] == 400


def test_handler_rejects_bad_token(rsa_key):
    resp = auth.handler(
        _event({"identityToken": _apple_token(rsa_key, aud="nope")}), None
    )
    assert resp["statusCode"] == 401


# --- /auth/refresh -----------------------------------------------------------


class _FakeSyncStore:
    """Only the revocation-marker read that refresh needs (see account.py)."""

    def __init__(self):
        self.items = {}

    def get(self, user_id, sk):
        return self.items.get((user_id, sk))


@pytest.fixture
def sync_store(monkeypatch):
    import account

    fake = _FakeSyncStore()
    monkeypatch.setattr(account, "_store", lambda: fake)
    return fake


def _session_token(iat_offset=-3600, ttl=7200, key=SESSION_KEY, **extra):
    now = int(time.time())
    claims = {
        "sub": "apple:u1",
        "iat": now + iat_offset,
        "exp": now + iat_offset + ttl,
        "email": "a@b.com",
    }
    claims.update(extra)
    import jwtlite

    return jwtlite.encode(claims, key)


def _refresh_event(token, path="/auth/refresh"):
    headers = {"content-type": "application/json"}
    if token is not None:
        headers["authorization"] = f"Bearer {token}"
    return {
        "rawPath": path,
        "requestContext": {"http": {"method": "POST", "path": path}},
        "headers": headers,
        "body": "",
        "isBase64Encoded": False,
    }


def test_refresh_mints_a_new_token_for_a_valid_session(sync_store):
    ten_days = 10 * 24 * 3600
    old = _session_token(iat_offset=-ten_days, ttl=60 * 24 * 3600)
    old_claims = session.verify_session_token(old, SESSION_KEY)

    resp = auth.handler(_refresh_event(old), None)
    assert resp["statusCode"] == 200
    out = json.loads(resp["body"])
    assert out["userId"] == "apple:u1"
    assert out["email"] == "a@b.com"
    assert out["expiresInSeconds"] == auth.SESSION_TTL_SECONDS
    new_claims = session.verify_session_token(out["sessionToken"], SESSION_KEY)
    assert new_claims["sub"] == "apple:u1"
    assert new_claims["email"] == "a@b.com"
    # A genuinely later expiry, dated from now — not a copy of the old token.
    assert new_claims["exp"] > old_claims["exp"]
    assert new_claims["iat"] >= int(time.time()) - 5
    assert out["sessionToken"] != old


def test_refresh_rejects_an_expired_token(sync_store):
    expired = _session_token(iat_offset=-7200, ttl=3600)
    resp = auth.handler(_refresh_event(expired), None)
    assert resp["statusCode"] == 401
    assert "Session expired" in json.loads(resp["body"])["error"]["message"]


def test_refresh_rejects_missing_or_forged_bearer(sync_store):
    assert auth.handler(_refresh_event(None), None)["statusCode"] == 401
    assert auth.handler(_refresh_event("garbage"), None)["statusCode"] == 401
    forged = _session_token(key="the-wrong-key-padding-0123456789abcdef")
    assert auth.handler(_refresh_event(forged), None)["statusCode"] == 401


def test_refresh_rejects_a_token_revoked_by_account_deletion(sync_store):
    import account

    token = _session_token(iat_offset=-600)
    # The account was deleted after this token was minted → every earlier token
    # is revoked, and refresh must not launder it into a fresh one.
    sync_store.items[("apple:u1", account.DELETED_MARKER_SK)] = {
        "userId": "apple:u1",
        "sk": account.DELETED_MARKER_SK,
        "minIat": int(time.time()) - 60,
    }
    resp = auth.handler(_refresh_event(token), None)
    assert resp["statusCode"] == 401

    # ...but a token minted AFTER the deletion (a fresh sign-in) refreshes fine.
    fresh = _session_token(iat_offset=0)
    assert auth.handler(_refresh_event(fresh), None)["statusCode"] == 200


def test_apple_sign_in_path_is_untouched_by_the_refresh_route(rsa_key, sync_store):
    # The shipped app's request, now carrying an explicit /auth/apple path.
    ev = _event({"identityToken": _apple_token(rsa_key)})
    ev["rawPath"] = "/auth/apple"
    ev["requestContext"] = {"http": {"method": "POST", "path": "/auth/apple"}}
    resp = auth.handler(ev, None)
    assert resp["statusCode"] == 200
    assert json.loads(resp["body"])["userId"] == "apple:000123.abc.def"


# --- session token round-trip ------------------------------------------------


def test_session_roundtrip():
    token = session.mint_session_token("apple:xyz", SESSION_KEY, 3600, email="a@b.com")
    claims = session.verify_session_token(token, SESSION_KEY)
    assert claims["sub"] == "apple:xyz"
    assert claims["email"] == "a@b.com"


def test_session_wrong_key_rejected():
    token = session.mint_session_token("apple:xyz", SESSION_KEY, 3600)
    with pytest.raises(common.ProxyError) as exc:
        session.verify_session_token(token, "the-wrong-key-padding-0123456789abcdef")
    assert exc.value.status == 401


def test_session_expired_rejected():
    token = session.mint_session_token("apple:xyz", SESSION_KEY, -10)
    with pytest.raises(common.ProxyError) as exc:
        session.verify_session_token(token, SESSION_KEY)
    assert exc.value.status == 401
