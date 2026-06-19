"""Sign in with Apple -> app session token (AWS Lambda, pure standard library).

The app performs the native Sign in with Apple flow and POSTs the resulting
identity token here. We verify it against Apple's public keys (JWKS, RS256),
then mint our own HS256 session token (see session.py) that the app sends on
every /sync call. No Apple private key is needed for the native iOS flow: the
identity token's audience is the app's own bundle id. No third-party packages —
verification is done with jwtlite so the Lambda bundle stays dependency-free.

Body: {"identityToken": "<jwt>", "rawNonce": "<optional>", "fullName": "<optional>"}
Returns: {"sessionToken", "userId", "email", "expiresInSeconds"}
"""

import hashlib
import json
import os
import time
import urllib.request

import jwtlite
from common import ProxyError, _get_secret, _parse_body, _response
from session import mint_session_token

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

# The bundle id the app signs in under = the identity token's audience.
APPLE_CLIENT_ID = os.environ.get("APPLE_CLIENT_ID", "")
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)
SESSION_TTL_SECONDS = int(os.environ.get("SESSION_TTL_DAYS", "60")) * 24 * 3600

# Apple's public keys, cached per cold start: {kid: (n_int, e_int)}.
_jwks_cache = None


def _fetch_apple_jwks():
    req = urllib.request.Request(
        APPLE_JWKS_URL, headers={"accept": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    keys = {}
    for k in data.get("keys", []):
        if k.get("kty") == "RSA" and k.get("kid") and k.get("n") and k.get("e"):
            n = int.from_bytes(jwtlite.b64url_decode(k["n"]), "big")
            e = int.from_bytes(jwtlite.b64url_decode(k["e"]), "big")
            keys[k["kid"]] = (n, e)
    return keys


def _apple_key_for_kid(kid):
    """Return the (n, e) public key for [kid], refetching once if Apple has
    rotated keys since the last cold start."""
    global _jwks_cache
    if _jwks_cache is None:
        _jwks_cache = _fetch_apple_jwks()
    if kid not in _jwks_cache:
        _jwks_cache = _fetch_apple_jwks()
    return _jwks_cache.get(kid)


def verify_apple_identity_token(identity_token, raw_nonce=None):
    """Verify an Apple identity token and return its claims. Raises ProxyError
    on any failure: bad signature / audience / issuer / expiry / nonce (401),
    a JWKS fetch problem (502), or missing configuration (500)."""
    if not APPLE_CLIENT_ID:
        # Server misconfiguration — never imply the user did something wrong.
        raise ProxyError(500, "Sign-in is not configured. Please try again later.")

    bad = "Could not verify your Apple sign-in. Please try again."
    try:
        header, payload, signing_input, signature = jwtlite.split(identity_token)
    except jwtlite.JwtError:
        raise ProxyError(401, bad)
    if header.get("alg") != "RS256":
        raise ProxyError(401, bad)

    try:
        key = _apple_key_for_kid(header.get("kid"))
    except Exception:  # JWKS fetch / network problem
        raise ProxyError(
            502, "Sign-in is unavailable right now. Please try again later."
        )
    if not key:
        raise ProxyError(401, bad)

    n, e = key
    if not jwtlite.verify_rs256(signing_input, signature, n, e):
        raise ProxyError(401, bad)

    if payload.get("iss") != APPLE_ISSUER:
        raise ProxyError(401, bad)
    # APPLE_CLIENT_ID may be a comma-separated list — e.g. the prod bundle id
    # plus the ".dev" build's id on the v2 stack — so accept a token issued for
    # any of them. (Single value behaves exactly as before.)
    accepted = {c.strip() for c in APPLE_CLIENT_ID.split(",") if c.strip()}
    aud = payload.get("aud")
    auds = {a for a in (aud if isinstance(aud, list) else [aud]) if a}
    if accepted.isdisjoint(auds):
        raise ProxyError(401, bad)
    exp = payload.get("exp")
    if not isinstance(exp, (int, float)) or int(time.time()) >= int(exp):
        raise ProxyError(401, bad)

    # When the client bound the request with a nonce, the token carries SHA-256
    # of the raw nonce. Checking it prevents replay of a captured token.
    if raw_nonce is not None:
        expected = hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest()
        if payload.get("nonce") != expected:
            raise ProxyError(401, bad)

    return payload


def handler(event, context):
    try:
        body = _parse_body(event)
        identity_token = body.get("identityToken")
        if not isinstance(identity_token, str) or not identity_token:
            raise ProxyError(400, "Missing identity token.")
        raw_nonce = body.get("rawNonce")

        claims = verify_apple_identity_token(identity_token, raw_nonce)
        sub = claims.get("sub")
        if not sub:
            raise ProxyError(
                401, "Could not verify your Apple sign-in. Please try again."
            )

        user_id = "apple:" + sub
        email = claims.get("email")
        signing_key = _get_secret(SESSION_KEY_PARAM)
        token = mint_session_token(
            user_id, signing_key, SESSION_TTL_SECONDS, email=email
        )
        return _response(
            200,
            {
                "sessionToken": token,
                "userId": user_id,
                "email": email,
                "expiresInSeconds": SESSION_TTL_SECONDS,
            },
        )
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(
            500, {"error": {"message": "Unexpected error. Please try again."}}
        )
