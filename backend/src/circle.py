"""Food at Peace — Circle of Food (AWS Lambda).

The real friend graph behind the social "Circle of Food" feature, authenticated
with the app session token (the same HS256 token /sync uses). One table holds a
handle directory plus the friendship edges; a connected friend's trend snapshot
is computed read-only from *their own* synced food + profile — privacy-gated to
mutually-connected friends and returned only as a daily aggregate, never raw
food.

Routes:
  POST /circle/register {handle, name?}    -> claim a unique @handle
  POST /circle/invite   {handle}           -> request to connect with @handle
  POST /circle/connect  {handle}           -> one-tap mutual connect (invite link/QR)
  POST /circle/respond  {userId, action}   -> accept | decline an incoming request
  POST /circle/remove   {userId}           -> remove a friend / cancel a request
  GET  /circle/list                        -> {me, connected[], incoming[], outgoing[]}

CircleTable layout:
  pk="handle#<h>", sk="handle"          -> {userId, name}        (unique directory)
  pk="user#<uid>", sk="me"              -> {handle, name}        (my own card)
  pk="user#<uid>", sk="friend#<other>"  -> {status, handle, name, updatedAt}
A relationship is two mirrored edges (one per direction).
"""

import json
import os
import re
import time
import datetime

import pushmsg
from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

CIRCLE_TABLE = os.environ.get("CIRCLE_TABLE", "")
SYNC_TABLE = os.environ.get("SYNC_TABLE", "")
# The durable meal-photo bucket (shared with mealphotos.py). We presign a GET for
# a friend's profile photo so connected friends can see each other's avatar.
MEAL_PHOTOS_BUCKET = os.environ.get("MEAL_PHOTOS_BUCKET", "")
_PROFILE_PHOTO_TTL = 6 * 60 * 60
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)

_HANDLE_RE = re.compile(r"^[a-z0-9_]{2,20}$")

# Mirror of nutrition_math.dart (kept server-side so a friend's target can be
# derived from their synced profile without shipping their HealthKit data).
_ACTIVITY = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "veryActive": 1.9,
}
_GOAL_ADJ = {"lose": -500.0, "maintain": 0.0, "gain": 400.0}

_ddb = None


def _resource():
    global _ddb
    if _ddb is None:
        import boto3  # lazy, like the other handlers

        _ddb = boto3.resource("dynamodb")
    return _ddb


def _circle():
    return _resource().Table(CIRCLE_TABLE)


def _sync():
    return _resource().Table(SYNC_TABLE)


_s3 = None


def _s3c():
    global _s3
    if _s3 is None:
        import boto3

        _s3 = boto3.client("s3")
    return _s3


def _profile_photo_url(uid):
    """A presigned GET URL for [uid]'s profile photo (the reserved
    `meal/<uid>/__profile__.jpg` object in the durable meal-photo store), or None
    when the store isn't configured. The object may not exist (no photo set) — the
    client simply falls back to initials when the URL 403s, so we never need a
    (costly) existence check here."""
    if not MEAL_PHOTOS_BUCKET:
        return None
    try:
        return _s3c().generate_presigned_url(
            "get_object",
            Params={"Bucket": MEAL_PHOTOS_BUCKET, "Key": f"meal/{uid}/__profile__.jpg"},
            ExpiresIn=_PROFILE_PHOTO_TTL,
        )
    except Exception:  # noqa: BLE001 — never let avatar presigning break the list
        return None


def _now_ms():
    return int(time.time() * 1000)


def _bearer(event):
    raw = _header(event, "authorization") or ""
    if raw.lower().startswith("bearer "):
        token = raw[7:].strip()
        if token:
            return token
    raise ProxyError(401, "Not authenticated.")


def _me(event):
    claims = verify_session_token(_bearer(event), _get_secret(SESSION_KEY_PARAM))
    uid = claims.get("sub")
    if not uid:
        raise ProxyError(401, "Not authenticated.")
    return uid


# --- Pure helpers (unit-tested) ---------------------------------------------

def normalize_handle(raw):
    """Lowercase, drop a leading '@', validate. Returns the handle or raises."""
    h = (raw or "").strip()
    if h.startswith("@"):
        h = h[1:]
    h = h.lower()
    if not _HANDLE_RE.match(h):
        raise ProxyError(
            400, "Handle must be 2–20 chars: letters, numbers, or underscore."
        )
    return h


def compute_target(profile_data):
    """Daily calorie target from a synced profile (Mifflin–St Jeor → TDEE → goal),
    honouring a manual override. 0 when the profile is unusable."""
    if not isinstance(profile_data, dict):
        return 0.0
    override = profile_data.get("calorieGoalOverride")
    if isinstance(override, (int, float)) and override > 0:
        return float(override)
    try:
        weight = float(profile_data["weightKg"])
        height = float(profile_data["heightCm"])
        age = int(profile_data["age"])
    except (KeyError, TypeError, ValueError):
        return 0.0
    bmr = 10 * weight + 6.25 * height - 5 * age
    bmr += 5 if profile_data.get("sex") == "male" else -161
    tdee = bmr * _ACTIVITY.get(profile_data.get("activity"), 1.55)
    return max(0.0, tdee + _GOAL_ADJ.get(profile_data.get("goal"), 0.0))


def _last_7_days(today=None):
    base = (
        datetime.datetime.strptime(today, "%Y-%m-%d")
        if today
        else datetime.datetime.now(datetime.timezone.utc)
    )
    return [(base - datetime.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]


def build_trend(profile_data, food_records, today=None):
    """A privacy-safe trend snapshot: per-day calories vs target for the last 7
    days, plus today's total, the target, an adherence %, and a logging streak.
    [food_records] are decoded food `data` dicts ({calories, timestamp})."""
    days = _last_7_days(today)
    target = compute_target(profile_data)
    by_day = {d: 0.0 for d in days}
    for rec in food_records:
        ts = rec.get("timestamp")
        if not isinstance(ts, str) or len(ts) < 10:
            continue
        day = ts[:10]  # ISO-8601 date prefix
        if day in by_day:
            by_day[day] += float(rec.get("calories") or 0)
    kcal = [round(by_day[d]) for d in days]
    if target > 0:
        adherence = [min(100, round(100 * k / target)) for k in kcal]
    else:
        adherence = [0 for _ in kcal]
    # Logging streak: consecutive most-recent days with any food logged.
    streak = 0
    for k in reversed(kcal):
        if k > 0:
            streak += 1
        else:
            break
    return {
        "streak": streak,
        "adh": adherence,
        "kcal": kcal[-1],
        "target": round(target),
    }


# --- Storage ----------------------------------------------------------------

def _friend_card(handle, name, status):
    return {"handle": "@" + handle, "name": name or handle, "status": status}


def _my_card(uid):
    return _circle().get_item(Key={"pk": f"user#{uid}", "sk": "me"}).get("Item")


def _lookup_handle(handle):
    item = _circle().get_item(Key={"pk": f"handle#{handle}", "sk": "handle"}).get("Item")
    return item  # {userId, name} or None


def _put_edge(owner, other, handle, name, status):
    _circle().put_item(
        Item={
            "pk": f"user#{owner}",
            "sk": f"friend#{other}",
            "status": status,
            "handle": handle,
            "name": name or handle,
            "updatedAt": _now_ms(),
        }
    )


def _get_edge(owner, other):
    return _circle().get_item(
        Key={"pk": f"user#{owner}", "sk": f"friend#{other}"}
    ).get("Item")


def _delete_edge(owner, other):
    _circle().delete_item(Key={"pk": f"user#{owner}", "sk": f"friend#{other}"})


def _friend_food(uid):
    """Decoded, non-deleted food `data` dicts for a user from the sync table."""
    from boto3.dynamodb.conditions import Key

    out, kwargs = [], {"KeyConditionExpression": Key("userId").eq(uid)}
    while True:
        resp = _sync().query(**kwargs)
        for item in resp.get("Items", []):
            if item.get("type") != "food" or item.get("deleted"):
                continue
            try:
                out.append(json.loads(item["data"]))
            except (KeyError, ValueError, TypeError):
                pass
        start = resp.get("LastEvaluatedKey")
        if not start:
            return out
        kwargs["ExclusiveStartKey"] = start


def _friend_profile(uid):
    item = _sync().get_item(Key={"userId": uid, "sk": "profile"}).get("Item")
    if not item or item.get("deleted"):
        return {}
    try:
        return json.loads(item["data"])
    except (KeyError, ValueError, TypeError):
        return {}


# --- Operations -------------------------------------------------------------

def register(uid, body):
    handle = normalize_handle(body.get("handle"))
    name = (body.get("name") or "").strip()[:60] or handle
    existing = _lookup_handle(handle)
    if existing and existing.get("userId") != uid:
        raise ProxyError(409, "That handle is taken.")
    # Free a previously-claimed handle if I'm changing it.
    mine = _my_card(uid)
    if mine and mine.get("handle") and mine["handle"] != handle:
        _circle().delete_item(Key={"pk": f"handle#{mine['handle']}", "sk": "handle"})
    _circle().put_item(Item={"pk": f"handle#{handle}", "sk": "handle", "userId": uid, "name": name})
    _circle().put_item(Item={"pk": f"user#{uid}", "sk": "me", "handle": handle, "name": name})
    return {"handle": "@" + handle, "name": name}


def invite(uid, body):
    mine = _my_card(uid)
    if not mine:
        raise ProxyError(400, "Claim a handle first.")
    target = _lookup_handle(normalize_handle(body.get("handle")))
    if not target:
        raise ProxyError(404, "No one with that handle.")
    tid = target["userId"]
    if tid == uid:
        raise ProxyError(400, "You can't invite yourself.")
    edge = _get_edge(uid, tid)
    if edge and edge.get("status") == "connected":
        return {"status": "connected"}
    if edge and edge.get("status") == "incoming":
        # They already invited me — inviting back accepts it.
        return respond(uid, {"userId": tid, "action": "accept"})
    target_handle = _circle().get_item(
        Key={"pk": f"user#{tid}", "sk": "me"}
    ).get("Item", {}).get("handle") or normalize_handle(body.get("handle"))
    _put_edge(uid, tid, "@" + target_handle, target.get("name"), "outgoing")
    _put_edge(tid, uid, "@" + mine["handle"], mine.get("name"), "incoming")
    _push(
        tid,
        pushmsg.text(
            "invite", _lang(tid), name=mine.get("name") or "@" + mine["handle"]
        ),
    )
    return {"status": "outgoing"}


def connect(uid, body):
    """Direct mutual connect from an invite link/QR. The inviter consented by
    sharing the link, so the receiver's tap connects both sides immediately (no
    separate approval). Unwanted connections can be pruned from the manage list.
    Idempotent."""
    mine = _my_card(uid)
    if not mine:
        raise ProxyError(400, "Claim a handle first.")
    handle = normalize_handle(body.get("handle"))
    target = _lookup_handle(handle)
    if not target:
        raise ProxyError(404, "No one with that handle.")
    tid = target["userId"]
    if tid == uid:
        raise ProxyError(400, "That's your own invite link.")
    target_handle = _circle().get_item(
        Key={"pk": f"user#{tid}", "sk": "me"}
    ).get("Item", {}).get("handle") or handle
    _put_edge(uid, tid, "@" + target_handle, target.get("name"), "connected")
    _put_edge(tid, uid, "@" + mine["handle"], mine.get("name"), "connected")
    return {
        "status": "connected",
        "handle": "@" + target_handle,
        "name": target.get("name"),
    }


def respond(uid, body):
    other = body.get("userId")
    action = body.get("action")
    if not other:
        raise ProxyError(400, "Missing userId.")
    edge = _get_edge(uid, other)
    if not edge or edge.get("status") != "incoming":
        raise ProxyError(404, "No pending request from that user.")
    if action == "accept":
        _circle().update_item(
            Key={"pk": f"user#{uid}", "sk": f"friend#{other}"},
            UpdateExpression="SET #s = :c, updatedAt = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":c": "connected", ":t": _now_ms()},
        )
        _circle().update_item(
            Key={"pk": f"user#{other}", "sk": f"friend#{uid}"},
            UpdateExpression="SET #s = :c, updatedAt = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":c": "connected", ":t": _now_ms()},
        )
        mine = _my_card(uid)
        _push(
            other,
            pushmsg.text(
                "accept", _lang(other), name=(mine or {}).get("name") or "A friend"
            ),
        )
        return {"status": "connected"}
    # decline
    _delete_edge(uid, other)
    _delete_edge(other, uid)
    return {"status": "declined"}


def remove(uid, body):
    other = body.get("userId")
    if not other:
        raise ProxyError(400, "Missing userId.")
    _delete_edge(uid, other)
    _delete_edge(other, uid)
    return {"status": "removed"}


def register_device(uid, body):
    """Store an APNs device token for the account (so we can push to it). Tokens
    are deduped by value (the sk) and cleaned up on the next push failure. An
    optional `lang` (e.g. 'en' / 'zh') is recorded so pushes to this user can be
    localized to their app language; absent → server defaults to English."""
    token = (body.get("token") or "").strip()
    if not token or len(token) > 200:
        raise ProxyError(400, "Missing device token.")
    item = {"pk": f"user#{uid}", "sk": f"device#{token}"}
    lang = (body.get("lang") or "").strip()[:16]
    if lang:
        item["lang"] = lang
    _circle().put_item(Item=item)
    return {"status": "registered"}


def _push(to_uid, title, body=""):
    """Best-effort Apple push to one user's devices (never raises)."""
    try:
        import apns

        apns.notify(_get_secret, _circle(), to_uid, title, body)
    except Exception:  # noqa: BLE001
        pass


def _lang(to_uid):
    """The recipient's app language for a localized push ('en' on any failure)."""
    try:
        import apns

        return apns.user_lang(_circle(), to_uid)
    except Exception:  # noqa: BLE001
        return "en"


def list_circle(uid):
    from boto3.dynamodb.conditions import Key

    mine = _my_card(uid)
    resp = _circle().query(
        KeyConditionExpression=Key("pk").eq(f"user#{uid}")
        & Key("sk").begins_with("friend#")
    )
    out = {
        "me": {
            "handle": "@" + mine["handle"],
            "name": mine.get("name"),
            "photoUrl": _profile_photo_url(uid),
        }
        if mine
        else None,
        "connected": [],
        "incoming": [],
        "outgoing": [],
    }
    for edge in resp.get("Items", []):
        other = edge["sk"].split("#", 1)[1]
        status = edge.get("status")
        friend = {
            "id": other,
            "name": edge.get("name"),
            "handle": edge.get("handle"),
            "status": status,
            "photoUrl": _profile_photo_url(other),
        }
        if status == "connected":
            friend.update(build_trend(_friend_profile(other), _friend_food(other)))
            out["connected"].append(friend)
        elif status == "incoming":
            out["incoming"].append(friend)
        elif status == "outgoing":
            out["outgoing"].append(friend)
    return out


def handler(event, context):
    try:
        uid = _me(event)
        http = event.get("requestContext", {}).get("http", {})
        method = (http.get("method") or "").upper()
        path = (http.get("path") or "").rsplit("/", 1)[-1]
        if method == "GET":
            return _response(200, list_circle(uid))
        body = _parse_body(event)
        op = {
            "register": register,
            "register-device": register_device,
            "invite": invite,
            "connect": connect,
            "respond": respond,
            "remove": remove,
        }.get(path)
        if not op:
            raise ProxyError(404, "Unknown action.")
        return _response(200, op(uid, body))
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(500, {"error": {"message": "Unexpected error."}})
