"""Food at Peace — Circle photo feed (AWS Lambda).

Ephemeral (3-day) food-photo posts shared to your Circle, with emoji reactions.
Session-token auth (same HS256 token as /sync); privacy-gated to mutually-
connected friends. Photos live in S3 (3-day lifecycle); post + reaction rows
live in a DynamoDB table with a 3-day TTL, so everything self-expires.

Routes:
  POST /circle/post   {image, mediaType, name, calories}  -> create a post
  GET  /circle/feed                                        -> friends' + own active posts + reactions
  POST /circle/react  {postId, emoji}                      -> toggle an emoji reaction

PostsTable layout (TTL on `expiresAt`, epoch seconds):
  pk="feed#<authorId>", sk="post#<createdMs>#<postId>"  -> {name, calories, photoKey, authorName, authorHandle, createdAt, expiresAt}
  pk="post#<postId>",   sk="react#<reactorId>"          -> {emoji, reactorName, postAuthorId, expiresAt}
S3 photo key: posts/<authorId>/<postId>.jpg
"""

import base64
import json
import os
import time
import uuid

from common import ProxyError, _get_secret, _header, _parse_body, _response
from session import verify_session_token

POSTS_TABLE = os.environ.get("POSTS_TABLE", "")
CIRCLE_TABLE = os.environ.get("CIRCLE_TABLE", "")
PHOTOS_BUCKET = os.environ.get("PHOTOS_BUCKET", "")
# The durable meal-photo bucket (shared with circle.py / mealphotos.py). We
# presign a GET for the post author's profile photo so their avatar shows on the
# feed card — matching the friend strip.
MEAL_PHOTOS_BUCKET = os.environ.get("MEAL_PHOTOS_BUCKET", "")
PROFILE_PHOTO_TTL = 6 * 60 * 60
SESSION_KEY_PARAM = os.environ.get(
    "SESSION_KEY_PARAM", "/food-at-peace/session-signing-key"
)
APP_TOKEN_PARAM = os.environ.get("APP_TOKEN_PARAM", "/food-at-peace/app-token")
# The creator's official @handle, whose posts a signed-out app may read publicly.
OFFICIAL_HANDLE = os.environ.get("OFFICIAL_HANDLE", "roro")

TTL_SECONDS = 3 * 24 * 60 * 60  # posts live 3 days
MAX_IMAGE_BYTES = 6 * 1024 * 1024
PHOTO_URL_TTL = 6 * 60 * 60  # presigned GET valid 6h (the app refetches the feed)

_ddb = None
_s3 = None


def _resource():
    global _ddb
    if _ddb is None:
        import boto3

        _ddb = boto3.resource("dynamodb")
    return _ddb


def _posts():
    return _resource().Table(POSTS_TABLE)


def _circle():
    return _resource().Table(CIRCLE_TABLE)


def _s3c():
    global _s3
    if _s3 is None:
        import boto3

        _s3 = boto3.client("s3")
    return _s3


def _now_ms():
    return int(time.time() * 1000)


def _now_s():
    return int(time.time())


def _bearer_token(event):
    raw = _header(event, "authorization") or ""
    return raw[7:].strip() if raw.lower().startswith("bearer ") else ""


def _app_token_ok(event):
    """True when the request carries the shared app token (a signed-out app)."""
    tok = _header(event, "x-app-token") or ""
    try:
        return bool(tok) and tok == _get_secret(APP_TOKEN_PARAM)
    except Exception:  # noqa: BLE001 — treat any secret-fetch failure as no-auth
        return False


def _me(event):
    token = _bearer_token(event)
    if not token:
        raise ProxyError(401, "Not authenticated.")
    uid = verify_session_token(token, _get_secret(SESSION_KEY_PARAM)).get("sub")
    if not uid:
        raise ProxyError(401, "Not authenticated.")
    return uid


def _user_card(uid):
    """The poster/reactor's circle {handle, name}, or a generic fallback."""
    item = _circle().get_item(Key={"pk": f"user#{uid}", "sk": "me"}).get("Item") or {}
    return {"handle": item.get("handle"), "name": item.get("name") or "Someone"}


def _profile_photo_url(uid):
    """A presigned GET URL for [uid]'s profile photo (the reserved
    `meal/<uid>/__profile__.jpg` object in the durable meal-photo store), or None
    when the store isn't configured. The object may not exist (no photo set) — the
    client falls back to initials when the URL 403s, so no existence check here.
    Mirrors circle.py so the feed avatar matches the friend strip."""
    if not MEAL_PHOTOS_BUCKET:
        return None
    try:
        return _s3c().generate_presigned_url(
            "get_object",
            Params={"Bucket": MEAL_PHOTOS_BUCKET, "Key": f"meal/{uid}/__profile__.jpg"},
            ExpiresIn=PROFILE_PHOTO_TTL,
        )
    except Exception:  # noqa: BLE001 — never let avatar presigning break the feed
        return None


def _connected_ids(uid):
    from boto3.dynamodb.conditions import Key

    resp = _circle().query(
        KeyConditionExpression=Key("pk").eq(f"user#{uid}")
        & Key("sk").begins_with("friend#")
    )
    return [
        edge["sk"].split("#", 1)[1]
        for edge in resp.get("Items", [])
        if edge.get("status") == "connected"
    ]


def _push(to_uid, title, body=""):
    """Best-effort Apple push to one user's devices (never raises)."""
    try:
        import apns

        apns.notify(_get_secret, _circle(), to_uid, title, body)
    except Exception:  # noqa: BLE001
        pass


# --- Operations -------------------------------------------------------------

def create_post(uid, body):
    image = body.get("image")
    if not isinstance(image, str) or not image:
        raise ProxyError(400, "No image provided.")
    try:
        raw = base64.b64decode(image)
    except Exception:
        raise ProxyError(400, "Bad image.")
    if not raw or len(raw) > MAX_IMAGE_BYTES:
        raise ProxyError(413, "That image is too large.")

    media = body.get("mediaType") or "image/jpeg"
    name = (body.get("name") or "").strip()[:120]
    calories = int(body.get("calories") or 0)
    post_id = uuid.uuid4().hex
    created = _now_ms()
    expires = _now_s() + TTL_SECONDS
    key = f"posts/{uid}/{post_id}.jpg"

    _s3c().put_object(Bucket=PHOTOS_BUCKET, Key=key, Body=raw, ContentType=media)
    me = _user_card(uid)
    _posts().put_item(
        Item={
            "pk": f"feed#{uid}",
            "sk": f"post#{created}#{post_id}",
            "postId": post_id,
            "authorId": uid,
            "authorName": me["name"],
            "authorHandle": me["handle"],
            "name": name,
            "calories": calories,
            "photoKey": key,
            "createdAt": created,
            "expiresAt": expires,
        }
    )
    # Tell connected friends a new meal landed in their circle (best-effort).
    for friend in _connected_ids(uid):
        _push(friend, f"{me['name']} shared a meal 🍵")
    return {"postId": post_id, "expiresAt": expires}


def _reactions_for(post_id, viewer_id, owner_view):
    """Returns ({emoji: count}, my_emoji, [reactors]) for a post. `reactors` is
    only populated for the post owner (so they 'receive' who reacted)."""
    from boto3.dynamodb.conditions import Key

    resp = _posts().query(
        KeyConditionExpression=Key("pk").eq(f"post#{post_id}")
        & Key("sk").begins_with("react#")
    )
    counts, mine, reactors = {}, None, []
    for r in resp.get("Items", []):
        emoji = r.get("emoji")
        if not emoji:
            continue
        counts[emoji] = counts.get(emoji, 0) + 1
        reactor = r["sk"].split("#", 1)[1]
        if reactor == viewer_id:
            mine = emoji
        if owner_view:
            reactors.append({"name": r.get("reactorName") or "Someone", "emoji": emoji})
    return counts, mine, reactors


def _user_posts(author_id, viewer_id):
    from boto3.dynamodb.conditions import Key

    now = _now_s()
    # The author's CURRENT name/handle (from their circle "me" card), not the
    # value denormalized onto each post at creation — so a later rename shows
    # everywhere and old posts never read as a stale name / "Someone".
    author = _user_card(author_id)
    author_photo = _profile_photo_url(author_id)  # one presign per author, not per post
    resp = _posts().query(
        KeyConditionExpression=Key("pk").eq(f"feed#{author_id}")
        & Key("sk").begins_with("post#"),
        ScanIndexForward=False,  # newest first
        Limit=30,
    )
    out = []
    for item in resp.get("Items", []):
        if int(item.get("expiresAt", 0)) <= now:
            continue  # expired but not yet TTL-reaped
        is_owner = author_id == viewer_id
        counts, mine, reactors = _reactions_for(item["postId"], viewer_id, is_owner)
        url = _s3c().generate_presigned_url(
            "get_object",
            Params={"Bucket": PHOTOS_BUCKET, "Key": item["photoKey"]},
            ExpiresIn=PHOTO_URL_TTL,
        )
        out.append(
            {
                "postId": item["postId"],
                "authorId": author_id,
                "authorName": author["name"],
                "authorHandle": author["handle"],
                "authorPhotoUrl": author_photo,
                "name": item.get("name"),
                "calories": int(item.get("calories", 0)),
                "createdAt": int(item.get("createdAt", 0)),
                "expiresAt": int(item.get("expiresAt", 0)),
                "photoUrl": url,
                "mine": is_owner,
                "reactions": counts,
                "myReaction": mine,
                "reactors": reactors,
            }
        )
    return out


def feed(uid):
    authors = [uid] + _connected_ids(uid)
    posts = []
    for author in authors:
        posts.extend(_user_posts(author, uid))
    posts.sort(key=lambda p: p["createdAt"], reverse=True)
    return {"posts": posts}


def official_feed():
    """The creator's official-account posts, readable WITHOUT an account (app
    token only) — so a signed-out / brand-new user still sees real photos in the
    feed before logging in. Public content: only the official account's own posts."""
    item = (
        _circle()
        .get_item(Key={"pk": f"handle#{OFFICIAL_HANDLE}", "sk": "handle"})
        .get("Item")
    )
    uid = (item or {}).get("userId")
    return {"posts": _user_posts(uid, None) if uid else []}


def react(uid, body):
    post_id = body.get("postId")
    emoji = (body.get("emoji") or "").strip()
    if not post_id:
        raise ProxyError(400, "Missing postId.")
    if len(emoji) > 12:
        raise ProxyError(400, "Bad reaction.")
    key = {"pk": f"post#{post_id}", "sk": f"react#{uid}"}
    existing = _posts().get_item(Key=key).get("Item")
    # Tapping the same emoji again clears it (toggle); empty also clears.
    if not emoji or (existing and existing.get("emoji") == emoji):
        _posts().delete_item(Key=key)
        return {"myReaction": None}
    reactor = _user_card(uid)["name"]
    _posts().put_item(
        Item={
            **key,
            "emoji": emoji,
            "reactorName": reactor,
            "expiresAt": _now_s() + TTL_SECONDS,
        }
    )
    # Notify the meal's owner that someone reacted (best-effort; authorId comes
    # from the client's feed entry).
    owner = (body.get("authorId") or "").strip()
    if owner and owner != uid:
        _push(owner, f"{reactor} reacted {emoji} to your meal")
    return {"myReaction": emoji}


def handler(event, context):
    try:
        http = event.get("requestContext", {}).get("http", {})
        method = (http.get("method") or "").upper()
        path = (http.get("path") or "").rsplit("/", 1)[-1]
        # Signed-out app (no Bearer session but a valid app token) → the public
        # official-creator feed, so new users see real photos before logging in.
        if method == "GET" and not _bearer_token(event) and _app_token_ok(event):
            return _response(200, official_feed())
        uid = _me(event)
        if method == "GET":
            return _response(200, feed(uid))
        body = _parse_body(event)
        if path == "post":
            return _response(200, create_post(uid, body))
        if path == "react":
            return _response(200, react(uid, body))
        raise ProxyError(404, "Unknown action.")
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(500, {"error": {"message": "Unexpected error."}})
