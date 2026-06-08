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
