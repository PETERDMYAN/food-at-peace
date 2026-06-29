"""Food at Peace — Circle photo feed (AWS Lambda).

Ephemeral (3-day) food-photo posts shared to your Circle, with emoji reactions.
Session-token auth (same HS256 token as /sync); privacy-gated to mutually-
connected friends. Photos live in S3 (3-day lifecycle); post + reaction rows
live in a DynamoDB table with a 3-day TTL, so everything self-expires.

Comments are PRIVATE per-commenter threads with the post owner as the hub: each
non-owner commenter has a 1:1 thread with the owner. The owner sees every thread
(all commenters + their own replies); a commenter sees ONLY their own thread
(their comments + the owner's replies to them) — never another commenter's. See
`.claude/skills/circle-comments-privacy/SKILL.md`.

Routes:
  POST /circle/post     {image, mediaType, name, calories}      -> create a post
  GET  /circle/feed                                              -> friends' + own active posts + reactions + commentCount
  POST /circle/react    {postId, emoji}                          -> toggle an emoji reaction
  POST /circle/comment  {postId, postAuthorId, text, threadUser?}-> add a comment (owner reply needs threadUser)
  POST /circle/comments {postId, postAuthorId}                   -> the comment threads visible to the caller
  POST /circle/comment/delete {postId, postAuthorId, commentId, threadUser} -> delete a comment (owner: any; author: own)

PostsTable layout (TTL on `expiresAt`, epoch seconds):
  pk="feed#<authorId>", sk="post#<createdMs>#<postId>"           -> {name, calories, photoKey, authorName, authorHandle, createdAt, expiresAt}
  pk="post#<postId>",   sk="react#<reactorId>"                   -> {emoji, reactorName, postAuthorId, expiresAt}
  pk="post#<postId>",   sk="comment#<threadUser>#<createdMs>#<commentId>" -> {text, authorId, isOwner, threadUser, postAuthorId, authorName, createdAt, expiresAt}
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
# Owner-only token (shared with beans.py) that gates publishing as the official
# account — the "push photo + text as Eva" capability.
ADMIN_TOKEN_PARAM = os.environ.get("ADMIN_TOKEN_PARAM", "/food-at-peace/admin-token")
# The creator's official @handle, whose posts a signed-out app may read publicly.
OFFICIAL_HANDLE = os.environ.get("OFFICIAL_HANDLE", "roro")
# The SECOND official account ("Eva"), a DISTINCT account from Roro. We surface
# her posts in the feed alongside Roro's so an owner can broadcast as Eva to
# everyone — Roro's handling is left completely untouched; Eva is only ADDED.
EVA_HANDLE = os.environ.get("EVA_HANDLE", "eva")

TTL_SECONDS = 3 * 24 * 60 * 60  # posts live 3 days
MAX_IMAGE_BYTES = 6 * 1024 * 1024
MAX_COMMENT_LEN = 500
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


def _admin_ok(event):
    """True when the request carries the owner-only admin token (same secret as
    beans.py's /beans/grant). Gates publishing as the official account."""
    tok = _header(event, "x-admin-token") or ""
    try:
        return bool(tok) and tok == _get_secret(ADMIN_TOKEN_PARAM)
    except Exception:  # noqa: BLE001 — any secret-fetch failure → not authorised
        return False


def _account_uid(handle):
    """The userId behind an official @handle, from the handle directory
    (pk='handle#<handle>'). None if it isn't registered. Lets the owner publish as
    a specific official account ('eva' vs 'roro' — they're separate accounts)."""
    h = (handle or "").strip().lower().lstrip("@")
    item = _circle().get_item(Key={"pk": f"handle#{h}", "sk": "handle"}).get("Item")
    return (item or {}).get("userId")


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


def _comment_notify_ok(uid):
    """Whether `uid` wants comment / reply / @-mention push notifications.
    Set via /circle/notify-prefs; absent → True, so existing users (and any read
    failure) keep getting them. Only an explicit `comments == False` mutes them."""
    try:
        item = (
            _circle().get_item(Key={"pk": f"user#{uid}", "sk": "notifyprefs"}).get("Item")
            or {}
        )
        return item.get("comments", True) is not False
    except Exception:  # noqa: BLE001 — never let a prefs read break commenting
        return True


# --- Operations -------------------------------------------------------------

def _decode_image(body):
    """Validate + decode a base64 image field. Returns (raw_bytes, media_type)."""
    image = body.get("image")
    if not isinstance(image, str) or not image:
        raise ProxyError(400, "No image provided.")
    try:
        raw = base64.b64decode(image)
    except Exception:
        raise ProxyError(400, "Bad image.")
    if not raw or len(raw) > MAX_IMAGE_BYTES:
        raise ProxyError(413, "That image is too large.")
    return raw, (body.get("mediaType") or "image/jpeg")


def _store_post(uid, raw, media, name, calories):
    """Upload the photo + write the feed row for a post by [uid]. Returns
    {postId, expiresAt, authorName}. Shared by create_post + official_post."""
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
    return {"postId": post_id, "expiresAt": expires, "authorName": me["name"]}


def create_post(uid, body):
    raw, media = _decode_image(body)
    name = (body.get("name") or "").strip()[:120]
    calories = int(body.get("calories") or 0)
    result = _store_post(uid, raw, media, name, calories)
    # Tell connected friends a new meal landed in their circle (best-effort).
    for friend in _connected_ids(uid):
        _push(friend, f"{result['authorName']} shared a meal 🍵")
    return {"postId": result["postId"], "expiresAt": result["expiresAt"]}


def official_post(body):
    """Owner-only: publish a photo + text post AS an official account. `handle`
    selects WHICH account ('eva' or 'roro' — they're DISTINCT official accounts);
    defaults to OFFICIAL_HANDLE. The post lands in that account's feed under its
    live name. Admin-token gated; reuses the post infra (3-day TTL). `text` →
    caption."""
    handle = body.get("handle") or OFFICIAL_HANDLE
    uid = _account_uid(handle)
    if not uid:
        raise ProxyError(404, "That account isn't registered.")
    raw, media = _decode_image(body)
    text = (body.get("text") or body.get("name") or "").strip()[:120]
    calories = int(body.get("calories") or 0)
    result = _store_post(uid, raw, media, text, calories)
    return {
        "postId": result["postId"],
        "expiresAt": result["expiresAt"],
        "author": result["authorName"],
        "handle": handle,
    }


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
        # Comments visible to THIS viewer (owner: every thread; friend: their own;
        # signed-out: none) — the count + the most recent few for an inline preview.
        vis = _visible_comments(item["postId"], viewer_id, is_owner)
        comment_count = len(vis)
        recent_comments = [_comment_preview(c) for c in vis[-3:]]
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
                "commentCount": comment_count,
                "recentComments": recent_comments,
            }
        )
    return out


def feed(uid):
    authors = [uid] + _connected_ids(uid)
    # Surface the Eva official account to EVERY user (Roro already reaches all via
    # auto-follow — his path is unchanged here; we only ADD Eva, and only if she
    # isn't already a connection, so nothing is ever doubled).
    eva = _account_uid(EVA_HANDLE)
    if eva and eva not in authors:
        authors.append(eva)
    posts = []
    for author in authors:
        posts.extend(_user_posts(author, uid))
    posts.sort(key=lambda p: p["createdAt"], reverse=True)
    return {"posts": posts}


def official_feed():
    """The official accounts' posts, readable WITHOUT an account (app token only)
    — so a signed-out / brand-new user still sees real photos before logging in.
    Public content: the official accounts' own posts — Roro (unchanged) plus Eva,
    added alongside so her broadcasts reach signed-out users too."""
    posts = []
    roro = _account_uid(OFFICIAL_HANDLE)  # the existing official feed, unchanged
    if roro:
        posts.extend(_user_posts(roro, None))
    eva = _account_uid(EVA_HANDLE)
    if eva:
        posts.extend(_user_posts(eva, None))
    posts.sort(key=lambda p: p["createdAt"], reverse=True)
    return {"posts": posts}


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


# --- Comments (private per-commenter threads + the owner's PUBLIC comments) ---

# A comment's threadUser scopes who sees it: a real commenter's id → a PRIVATE
# thread (only that commenter + the owner); this sentinel → the owner's PUBLIC
# comments, visible to EVERYONE who can see the post. (Real ids contain ":", so
# there's no collision with a user id.)
_PUBLIC = "__public__"


def _find_post(author_id, post_id):
    """The author's active (non-expired) post with this id, or None. Authoritative
    ownership: a (post_id, author_id) pair only resolves if that post really
    exists under that author, so a client can't claim a different owner and leak
    another commenter's thread."""
    from boto3.dynamodb.conditions import Key

    if not author_id or not post_id:
        return None
    now = _now_s()
    resp = _posts().query(
        KeyConditionExpression=Key("pk").eq(f"feed#{author_id}")
        & Key("sk").begins_with("post#"),
        ScanIndexForward=False,
        Limit=100,
    )
    for item in resp.get("Items", []):
        if item.get("postId") == post_id and int(item.get("expiresAt", 0)) > now:
            return item
    return None


def _comments_q(post_id, prefix):
    """Comment rows on a post whose sk starts with `prefix`, oldest first.
    prefix "comment#" → all threads (owner view); "comment#<uid>#" → one thread."""
    from boto3.dynamodb.conditions import Key

    resp = _posts().query(
        KeyConditionExpression=Key("pk").eq(f"post#{post_id}")
        & Key("sk").begins_with(prefix),
        ScanIndexForward=True,
    )
    return resp.get("Items", [])


def _visible_comments(post_id, viewer_id, owner_view):
    """Comments on `post_id` visible to the viewer, oldest-first: the owner sees
    everything (public + every private thread); a commenter sees the public
    comments + their own thread; signed-out sees the public comments only."""
    if owner_view:
        rows = _comments_q(post_id, "comment#")  # public + every private thread
    elif viewer_id:
        rows = _comments_q(post_id, f"comment#{_PUBLIC}#") + _comments_q(
            post_id, f"comment#{viewer_id}#"
        )
    else:
        rows = _comments_q(post_id, f"comment#{_PUBLIC}#")  # signed-out: public only
    rows.sort(key=lambda r: int(r.get("createdAt", 0)))
    return rows


def _comment_preview(c):
    """A compact comment for the feed card's inline preview (denormalized name —
    the full sheet resolves live names)."""
    return {
        "commentId": c.get("commentId"),
        "authorName": c.get("authorName") or "Someone",
        "isOwner": bool(c.get("isOwner")),
        "public": bool(c.get("public")),
        "text": c.get("text") or "",
        "createdAt": int(c.get("createdAt", 0)),
    }


def _comment_count(post_id, viewer_id, owner_view):
    """How many comments `viewer_id` may see on `post_id` (public + the threads
    they're allowed to see)."""
    return len(_visible_comments(post_id, viewer_id, owner_view))


def create_comment(uid, body):
    """Add a comment. A non-owner opens/continues their own private thread; the
    owner replies INTO an existing commenter's thread (threadUser required)."""
    post_id = (body.get("postId") or "").strip()
    post_author = (body.get("postAuthorId") or "").strip()
    text = (body.get("text") or "").strip()
    if not post_id or not post_author:
        raise ProxyError(400, "Missing post.")
    if not text:
        raise ProxyError(400, "Empty comment.")
    text = text[:MAX_COMMENT_LEN]
    post = _find_post(post_author, post_id)
    if not post:
        raise ProxyError(404, "That post is no longer available.")
    owner = post_author
    is_owner = uid == owner
    public = bool(body.get("public"))
    owner_started_thread = False  # owner opened a NEW private thread (an @-mention)
    if is_owner and public:
        # The owner broadcasts: a PUBLIC comment everyone who sees the post sees.
        thread_user = _PUBLIC
    elif is_owner:
        # A PRIVATE comment to ONE person: either replying into their existing
        # thread, or STARTING one by @-mentioning a connected friend. Either way
        # only the owner + that one person ever see it.
        thread_user = (body.get("threadUser") or "").strip()
        if not thread_user or thread_user in (owner, _PUBLIC):
            raise ProxyError(400, "Choose whose comment to reply to, or comment publicly.")
        if not _comments_q(post_id, f"comment#{thread_user}#"):
            # No prior comment from them → the owner is opening a fresh private
            # thread; allowed only toward a connected friend (never an arbitrary id).
            if thread_user not in _connected_ids(owner):
                raise ProxyError(400, "You can only privately comment to a connected friend.")
            owner_started_thread = True
    else:
        # A non-owner always comments into their OWN private thread (only they +
        # the owner); they can't broadcast publicly.
        if owner not in _connected_ids(uid):
            raise ProxyError(403, "You can only comment on your friends' posts.")
        thread_user = uid
    me = _user_card(uid)
    created = _now_ms()
    comment_id = uuid.uuid4().hex
    _posts().put_item(
        Item={
            "pk": f"post#{post_id}",
            "sk": f"comment#{thread_user}#{created}#{comment_id}",
            "commentId": comment_id,
            "postId": post_id,
            "postAuthorId": owner,
            "threadUser": thread_user,
            "authorId": uid,
            "authorName": me["name"],
            "authorHandle": me["handle"],
            "isOwner": is_owner,
            "public": thread_user == _PUBLIC,
            "text": text,
            "createdAt": created,
            "expiresAt": _now_s() + TTL_SECONDS,
        }
    )
    # Best-effort push to the other side of the thread (a public broadcast has no
    # single recipient).
    if thread_user == _PUBLIC:
        pass
    elif is_owner:
        # An @-mention that opens a new private thread reads differently from a
        # reply into an existing one — but both ping the one recipient (if they
        # haven't muted comment notifications).
        if _comment_notify_ok(thread_user):
            if owner_started_thread:
                _push(thread_user, f"{me['name']} mentioned you in a comment 💬")
            else:
                _push(thread_user, f"{me['name']} replied to your comment 💬")
    elif _comment_notify_ok(owner):
        _push(owner, f"{me['name']} commented on your meal 💬")
    return {"commentId": comment_id, "createdAt": created, "public": thread_user == _PUBLIC}


def _thread_json(thread_user, items, owner_card):
    """One thread as JSON. Author display names are resolved live from the two
    participants' circle cards (owner + the commenter) so renames aren't stale."""
    viewer_card = owner_card if thread_user == owner_card.get("_id") else _user_card(thread_user)
    items = sorted(items, key=lambda r: int(r.get("createdAt", 0)))
    return {
        "user": {
            "id": thread_user,
            "handle": viewer_card["handle"],
            "name": viewer_card["name"],
        },
        "comments": [
            {
                "commentId": c.get("commentId"),
                "authorId": c.get("authorId"),
                "authorName": owner_card["name"] if c.get("isOwner") else viewer_card["name"],
                "authorHandle": owner_card["handle"]
                if c.get("isOwner")
                else viewer_card["handle"],
                "isOwner": bool(c.get("isOwner")),
                "text": c.get("text") or "",
                "createdAt": int(c.get("createdAt", 0)),
            }
            for c in items
        ],
    }


def list_comments(uid, body):
    """The comments visible to `uid`: the owner's PUBLIC comments (everyone) plus
    the private threads they may see — every thread for the post owner, only the
    caller's own for a connected commenter."""
    post_id = (body.get("postId") or "").strip()
    post_author = (body.get("postAuthorId") or "").strip()
    if not post_id or not post_author:
        raise ProxyError(400, "Missing post.")
    post = _find_post(post_author, post_id)
    if not post:
        raise ProxyError(404, "That post is no longer available.")
    owner = post_author
    is_owner = uid == owner
    if not is_owner and owner not in _connected_ids(uid):
        raise ProxyError(403, "You can't view these comments.")
    owner_card = dict(_user_card(owner))
    owner_card["_id"] = owner
    # Public comments (the owner's broadcasts) — visible to everyone.
    public = [
        {
            "commentId": c.get("commentId"),
            "authorId": c.get("authorId"),
            "authorName": owner_card["name"],
            "authorHandle": owner_card["handle"],
            "isOwner": True,
            "public": True,
            "text": c.get("text") or "",
            "createdAt": int(c.get("createdAt", 0)),
        }
        for c in sorted(
            _comments_q(post_id, f"comment#{_PUBLIC}#"),
            key=lambda r: int(r.get("createdAt", 0)),
        )
    ]
    # Private threads: every thread for the owner; just the caller's own otherwise.
    if is_owner:
        rows = [
            r for r in _comments_q(post_id, "comment#") if r.get("threadUser") != _PUBLIC
        ]
    else:
        rows = _comments_q(post_id, f"comment#{uid}#")
    grouped = {}
    for r in rows:
        grouped.setdefault(r.get("threadUser"), []).append(r)
    threads = [_thread_json(tu, items, owner_card) for tu, items in grouped.items()]
    # Most-recently-active thread first (matters only for the owner's many threads).
    threads.sort(
        key=lambda th: th["comments"][-1]["createdAt"] if th["comments"] else 0,
        reverse=True,
    )
    return {"isOwner": is_owner, "public": public, "threads": threads}


def delete_comment(uid, body):
    """Delete one comment. The **post owner** may delete any comment on their
    post; a **commenter** may delete their own. `threadUser` scopes the lookup to
    the right private thread."""
    post_id = (body.get("postId") or "").strip()
    post_author = (body.get("postAuthorId") or "").strip()
    comment_id = (body.get("commentId") or "").strip()
    thread_user = (body.get("threadUser") or "").strip()
    if not post_id or not post_author or not comment_id or not thread_user:
        raise ProxyError(400, "Missing fields.")
    post = _find_post(post_author, post_id)
    if not post:
        raise ProxyError(404, "That post is no longer available.")
    owner = post_author
    target = next(
        (
            r
            for r in _comments_q(post_id, f"comment#{thread_user}#")
            if r.get("commentId") == comment_id
        ),
        None,
    )
    if not target:
        raise ProxyError(404, "Comment not found.")
    # Owner deletes anything on their post; otherwise only your own comment.
    if uid != owner and uid != target.get("authorId"):
        raise ProxyError(403, "You can't delete that comment.")
    _posts().delete_item(Key={"pk": f"post#{post_id}", "sk": target["sk"]})
    return {"deleted": True}


def handler(event, context):
    try:
        http = event.get("requestContext", {}).get("http", {})
        method = (http.get("method") or "").upper()
        path = (http.get("path") or "").rsplit("/", 1)[-1]
        # Signed-out app (no Bearer session but a valid app token) → the public
        # official-creator feed, so new users see real photos before logging in.
        if method == "GET" and not _bearer_token(event) and _app_token_ok(event):
            return _response(200, official_feed())
        # Owner-only: publish a post AS the official account (admin-token gated, no
        # session) — the "push photo + text as Eva" capability.
        if method == "POST" and path == "official-post":
            if not _admin_ok(event):
                raise ProxyError(403, "Not authorized.")
            return _response(200, official_post(_parse_body(event)))
        uid = _me(event)
        if method == "GET":
            return _response(200, feed(uid))
        body = _parse_body(event)
        if path == "post":
            return _response(200, create_post(uid, body))
        if path == "react":
            return _response(200, react(uid, body))
        if path == "comment":
            return _response(200, create_comment(uid, body))
        if path == "comments":
            return _response(200, list_comments(uid, body))
        if path == "delete":  # /circle/comment/delete
            return _response(200, delete_comment(uid, body))
        raise ProxyError(404, "Unknown action.")
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(500, {"error": {"message": "Unexpected error."}})
