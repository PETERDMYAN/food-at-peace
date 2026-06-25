"""Best-effort Apple Push Notifications (APNs) sender — pure-Python deps only.

Sends a simple alert to a user's registered device tokens. Signs the APNs
provider JWT (ES256) with the .p8 key from SSM using the pure-Python `ecdsa`
lib (so `sam build` needs no Docker / native wheels), and posts over HTTP/2 via
`httpx[http2]`. EVERYTHING is wrapped so a failure never reaches the caller —
push is a nicety on top of the in-app + on-open notifications, never a hard dep.

Config:
  SSM /food-at-peace/apns-key     (SecureString)  the .p8 contents
  SSM /food-at-peace/apns-key-id  (String)        the 10-char key id
  env APNS_TEAM_ID                                Apple team id (JWT issuer)
  env APNS_BUNDLE_ID                              app bundle id (apns-topic)
  env APNS_HOST   default api.push.apple.com      (api.sandbox.push.apple.com for dev)
Device tokens live in the circle table: pk="user#<uid>", sk="device#<token>".
"""

import base64
import hashlib
import json
import os
import time

APNS_KEY_PARAM = os.environ.get("APNS_KEY_PARAM", "/food-at-peace/apns-key")
APNS_KEY_ID_PARAM = os.environ.get("APNS_KEY_ID_PARAM", "/food-at-peace/apns-key-id")
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID", "")
APNS_BUNDLE_ID = os.environ.get("APNS_BUNDLE_ID", "")
APNS_HOST = os.environ.get("APNS_HOST", "api.push.apple.com")

_jwt_cache = {"token": None, "iat": 0}


def _b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _provider_jwt(get_secret):
    """A cached APNs provider token (valid up to 1h; refresh ~every 50 min)."""
    now = int(time.time())
    if _jwt_cache["token"] and now - _jwt_cache["iat"] < 3000:
        return _jwt_cache["token"]
    import ecdsa  # pure-Python ES256 signing

    p8 = get_secret(APNS_KEY_PARAM)
    kid = get_secret(APNS_KEY_ID_PARAM)
    header = _b64(json.dumps({"alg": "ES256", "kid": kid}, separators=(",", ":")).encode())
    payload = _b64(json.dumps({"iss": APNS_TEAM_ID, "iat": now}, separators=(",", ":")).encode())
    signing_input = f"{header}.{payload}".encode("ascii")
    sk = ecdsa.SigningKey.from_pem(p8)
    sig = sk.sign_deterministic(
        signing_input, hashfunc=hashlib.sha256, sigencode=ecdsa.util.sigencode_string
    )  # JWS ES256 = raw r||s (64 bytes for P-256)
    token = f"{header}.{payload}.{_b64(sig)}"
    _jwt_cache.update(token=token, iat=now)
    return token


def device_tokens(circle_table, uid):
    """Every APNs device token registered for [uid] (empty on any failure)."""
    try:
        from boto3.dynamodb.conditions import Key

        resp = circle_table.query(
            KeyConditionExpression=Key("pk").eq(f"user#{uid}")
            & Key("sk").begins_with("device#")
        )
        return [i["sk"].split("#", 1)[1] for i in resp.get("Items", [])]
    except Exception:  # noqa: BLE001
        return []


def user_lang(circle_table, uid, default="en"):
    """[uid]'s preferred language (e.g. 'en' / 'zh'), read from any of their
    registered device rows, so a push can be localized to the recipient. Returns
    [default] when no device carries a lang (older clients didn't send one) or on
    any failure — keeping the pre-localization English behavior."""
    try:
        from boto3.dynamodb.conditions import Key

        resp = circle_table.query(
            KeyConditionExpression=Key("pk").eq(f"user#{uid}")
            & Key("sk").begins_with("device#")
        )
        for item in resp.get("Items", []):
            lang = (item.get("lang") or "").strip()
            if lang:
                return lang
    except Exception:  # noqa: BLE001
        pass
    return default


def send(get_secret, tokens, title, body):
    """Best-effort: push {title, body} to each token. Never raises."""
    if not tokens or not APNS_TEAM_ID or not APNS_BUNDLE_ID:
        return
    try:
        import httpx

        jwt_token = _provider_jwt(get_secret)
        payload = json.dumps(
            {"aps": {"alert": {"title": title, "body": body}, "sound": "default"}}
        )
        headers = {
            "authorization": f"bearer {jwt_token}",
            "apns-topic": APNS_BUNDLE_ID,
            "apns-push-type": "alert",
        }
        with httpx.Client(http2=True, timeout=10) as client:
            for token in tokens:
                try:
                    client.post(
                        f"https://{APNS_HOST}/3/device/{token}",
                        content=payload,
                        headers=headers,
                    )
                except Exception:  # noqa: BLE001 — one bad token shouldn't stop the rest
                    pass
    except Exception:  # noqa: BLE001 — push is best-effort
        pass


def notify(get_secret, circle_table, uid, title, body):
    """Convenience: look up [uid]'s tokens and push. Best-effort."""
    send(get_secret, device_tokens(circle_table, uid), title, body)
