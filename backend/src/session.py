"""App-issued session tokens (HS256, pure standard library via jwtlite).

Minted by the auth handler after a provider sign-in is verified, and checked by
the sync handler on every request. Signed with a secret held in SSM so nothing
sensitive ships in the app. The functions take the signing key as an argument
(the handlers fetch it from SSM) so they stay pure and testable.
"""

import time

import jwtlite
from common import ProxyError


def mint_session_token(user_id, signing_key, ttl_seconds, email=None):
    """Return a signed session token for [user_id], valid for [ttl_seconds]."""
    now = int(time.time())
    claims = {"sub": user_id, "iat": now, "exp": now + ttl_seconds}
    if email:
        claims["email"] = email
    return jwtlite.encode(claims, signing_key)


def verify_session_token(token, signing_key):
    """Return the claims of a valid session token, or raise ProxyError(401)."""
    try:
        header, payload, signing_input, signature = jwtlite.split(token)
    except jwtlite.JwtError:
        raise ProxyError(401, "Not authenticated.")

    if header.get("alg") != "HS256" or not jwtlite.verify_hs256(
        signing_input, signature, signing_key
    ):
        raise ProxyError(401, "Not authenticated.")

    exp = payload.get("exp")
    if not isinstance(exp, (int, float)) or int(time.time()) >= int(exp):
        raise ProxyError(401, "Session expired. Please sign in again.")
    return payload
