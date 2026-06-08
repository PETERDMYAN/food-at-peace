"""Minimal JWT primitives using only the Python standard library.

Keeps the Lambda bundle dependency-free (no PyJWT / cryptography), so `sam build`
needs no Docker / cross-compilation. Scope is exactly what this app needs:

- HS256 signing (our own session tokens), via hmac + sha256.
- RS256 *verification* (Apple identity tokens), via a pow()-based RSASSA-PKCS1
  -v1_5 check. This is a public-key operation (no secret, so no timing concern),
  and the *entire* encoded message is reconstructed and compared in constant time
  — which is what makes PKCS#1 v1.5 verification safe against signature forgery.
"""

import base64
import hashlib
import hmac
import json

# ASN.1 DigestInfo prefix for SHA-256 (EMSA-PKCS1-v1_5).
_SHA256_DIGEST_INFO = bytes.fromhex("3031300d060960864801650304020105000420")


class JwtError(Exception):
    """Malformed or unverifiable token."""


def b64url_decode(segment):
    if isinstance(segment, str):
        segment = segment.encode("ascii")
    return base64.urlsafe_b64decode(segment + b"=" * (-len(segment) % 4))


def b64url_encode(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def encode(claims, signing_key, headers=None):
    """Encode an HS256 JWT (used for our session tokens)."""
    header = {"alg": "HS256", "typ": "JWT"}
    if headers:
        header.update(headers)
    h = b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    p = b64url_encode(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
    signing_input = (h + "." + p).encode("ascii")
    sig = b64url_encode(_hs256(signing_input, signing_key))
    return f"{h}.{p}.{sig}"


def split(token):
    """Return (header, payload, signing_input_bytes, signature_bytes)."""
    try:
        h_b64, p_b64, s_b64 = token.split(".")
        header = json.loads(b64url_decode(h_b64))
        payload = json.loads(b64url_decode(p_b64))
        signature = b64url_decode(s_b64)
    except (ValueError, TypeError, AttributeError):
        raise JwtError("Malformed token.")
    if not isinstance(header, dict) or not isinstance(payload, dict):
        raise JwtError("Malformed token.")
    return header, payload, (h_b64 + "." + p_b64).encode("ascii"), signature


def _hs256(signing_input, key):
    if isinstance(key, str):
        key = key.encode("utf-8")
    return hmac.new(key, signing_input, hashlib.sha256).digest()


def verify_hs256(signing_input, signature, key):
    return hmac.compare_digest(_hs256(signing_input, key), signature)


def verify_rs256(signing_input, signature, n, e):
    """Verify an RSASSA-PKCS1-v1_5 / SHA-256 signature given the public key's
    modulus [n] and exponent [e] (ints). Returns True/False."""
    k = (n.bit_length() + 7) // 8
    if len(signature) != k:
        return False
    s = int.from_bytes(signature, "big")
    if s >= n:
        return False
    em = pow(s, e, n).to_bytes(k, "big")
    t = _SHA256_DIGEST_INFO + hashlib.sha256(signing_input).digest()
    ps_len = k - len(t) - 3
    if ps_len < 8:
        return False
    expected = b"\x00\x01" + b"\xff" * ps_len + b"\x00" + t
    return hmac.compare_digest(em, expected)
