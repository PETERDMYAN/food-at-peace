import base64

import pytest

import posts


class _FakePosts:
    def __init__(self):
        self.items = {}

    def get_item(self, Key):
        k = (Key["pk"], Key["sk"])
        return {"Item": self.items[k]} if k in self.items else {}

    def put_item(self, Item):
        self.items[(Item["pk"], Item["sk"])] = Item

    def delete_item(self, Key):
        self.items.pop((Key["pk"], Key["sk"]), None)


@pytest.fixture
def fake(monkeypatch):
    t = _FakePosts()
    monkeypatch.setattr(posts, "_posts", lambda: t)
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": "h", "name": "Tester"})
    return t


def test_react_toggles(fake):
    assert posts.react("u1", {"postId": "p1", "emoji": "👍"}) == {"myReaction": "👍"}
    assert ("post#p1", "react#u1") in fake.items
    # tapping the same emoji again clears it
    assert posts.react("u1", {"postId": "p1", "emoji": "👍"}) == {"myReaction": None}
    assert ("post#p1", "react#u1") not in fake.items
    # a different emoji replaces
    posts.react("u1", {"postId": "p1", "emoji": "❤️"})
    assert fake.items[("post#p1", "react#u1")]["emoji"] == "❤️"


def test_react_requires_postid(fake):
    with pytest.raises(posts.ProxyError):
        posts.react("u1", {"emoji": "👍"})


def test_feed_uses_current_author_name_not_stale(monkeypatch):
    """A post keeps the author's name from post-time; the feed must instead show
    the author's CURRENT name/handle (their 'me' card) — so a rename isn't stuck
    as a stale label / 'Someone' on old posts."""

    class _Q:
        def query(self, **kw):
            return {
                "Items": [
                    {
                        "postId": "p1",
                        "authorName": "StaleOldName",  # stored at post-time
                        "authorHandle": "oldhandle",
                        "name": "Soup",
                        "calories": 100,
                        "createdAt": 1,
                        "expiresAt": 10**12,  # far future → not expired
                        "photoKey": "posts/a/p1.jpg",
                    }
                ]
            }

    class _S3:
        def generate_presigned_url(self, *a, **k):
            return "https://signed"

    monkeypatch.setattr(posts, "_posts", lambda: _Q())
    monkeypatch.setattr(
        posts, "_user_card", lambda uid: {"handle": "currenthandle", "name": "Roro"}
    )
    monkeypatch.setattr(posts, "_reactions_for", lambda *a: ({}, None, []))
    monkeypatch.setattr(posts, "_s3c", lambda: _S3())

    out = posts._user_posts("author1", "viewer1")
    assert len(out) == 1
    assert out[0]["authorName"] == "Roro"  # current, not the stale stored value
    assert out[0]["authorHandle"] == "currenthandle"


def test_feed_includes_author_profile_photo_url(monkeypatch):
    """Each post carries the author's presigned profile-photo URL (one presign per
    author) so the feed card avatar matches the friend strip; null when unset."""

    class _Q:
        def query(self, **kw):
            return {
                "Items": [
                    {
                        "postId": "p1",
                        "name": "Soup",
                        "calories": 100,
                        "createdAt": 1,
                        "expiresAt": 10**12,
                        "photoKey": "posts/a/p1.jpg",
                    }
                ]
            }

    class _S3:
        def generate_presigned_url(self, *a, **k):
            return "https://signed-meal-photo"

    monkeypatch.setattr(posts, "_posts", lambda: _Q())
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": "h", "name": "Roro"})
    monkeypatch.setattr(posts, "_reactions_for", lambda *a: ({}, None, []))
    monkeypatch.setattr(posts, "_s3c", lambda: _S3())
    monkeypatch.setattr(posts, "MEAL_PHOTOS_BUCKET", "meal-bucket")

    out = posts._user_posts("author1", "viewer1")
    assert out[0]["authorPhotoUrl"] == "https://signed-meal-photo"


def test_feed_author_photo_null_when_store_unconfigured(monkeypatch):
    class _Q:
        def query(self, **kw):
            return {
                "Items": [
                    {
                        "postId": "p1",
                        "createdAt": 1,
                        "expiresAt": 10**12,
                        "photoKey": "posts/a/p1.jpg",
                    }
                ]
            }

    class _S3:
        def generate_presigned_url(self, *a, **k):
            return "https://signed"

    monkeypatch.setattr(posts, "_posts", lambda: _Q())
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": "h", "name": "X"})
    monkeypatch.setattr(posts, "_reactions_for", lambda *a: ({}, None, []))
    monkeypatch.setattr(posts, "_s3c", lambda: _S3())
    monkeypatch.setattr(posts, "MEAL_PHOTOS_BUCKET", "")  # unconfigured

    out = posts._user_posts("author1", "viewer1")
    assert out[0]["authorPhotoUrl"] is None


def test_create_post_rejects_missing_and_oversized_image(monkeypatch):
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": None, "name": "X"})
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {})  # no image
    big = base64.b64encode(b"x" * (posts.MAX_IMAGE_BYTES + 10)).decode()
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {"image": big})  # too large


def test_official_feed_returns_roro_and_eva_posts(monkeypatch):
    """A signed-out viewer's official feed = BOTH official accounts' own posts
    (Roro — unchanged — plus Eva), looked up by handle, public (viewer None)."""

    class _Circle:
        def get_item(self, Key):
            uid = {
                f"handle#{posts.OFFICIAL_HANDLE}": "roro-uid",
                f"handle#{posts.EVA_HANDLE}": "eva-uid",
            }.get(Key["pk"])
            return {"Item": {"userId": uid}} if uid else {}

    monkeypatch.setattr(posts, "_circle", lambda: _Circle())
    monkeypatch.setattr(
        posts,
        "_user_posts",
        lambda uid, viewer: [{"postId": f"p_{uid}", "authorId": uid, "createdAt": 1}]
        if viewer is None
        else [],
    )
    out = posts.official_feed()
    assert {p["authorId"] for p in out["posts"]} == {"roro-uid", "eva-uid"}


def test_official_feed_empty_when_no_official_account(monkeypatch):
    class _Circle:
        def get_item(self, Key):
            return {}

    monkeypatch.setattr(posts, "_circle", lambda: _Circle())
    assert posts.official_feed() == {"posts": []}


# --- Comments: private per-commenter threads, owner is the hub ---------------


def _cond(expr):
    """Extract (pk_eq, sk_begins_with) from a boto3 KeyConditionExpression so the
    in-memory fake can answer Query the way DynamoDB would."""
    pk = sk = None

    def walk(node):
        nonlocal pk, sk
        e = node.get_expression()
        op, vals = e["operator"], e["values"]
        if op == "AND":
            for v in vals:
                walk(v)
        elif op == "=" and getattr(vals[0], "name", None) == "pk":
            pk = vals[1]
        elif op == "begins_with" and getattr(vals[0], "name", None) == "sk":
            sk = vals[1]

    walk(expr)
    return pk, sk


class _CommentTable:
    """A minimal pk/sk DynamoDB stand-in that understands begins_with Query +
    Select=COUNT + ScanIndexForward, enough to exercise the comment logic."""

    def __init__(self):
        self.items = {}

    def put_item(self, Item):
        self.items[(Item["pk"], Item["sk"])] = Item

    def get_item(self, Key):
        k = (Key["pk"], Key["sk"])
        return {"Item": self.items[k]} if k in self.items else {}

    def delete_item(self, Key):
        self.items.pop((Key["pk"], Key["sk"]), None)

    def query(self, KeyConditionExpression=None, Select=None,
              ScanIndexForward=True, Limit=None, **kw):
        pk, prefix = _cond(KeyConditionExpression)
        rows = [
            v for (p, s), v in self.items.items()
            if p == pk and (prefix is None or s.startswith(prefix))
        ]
        rows.sort(key=lambda r: r["sk"], reverse=not ScanIndexForward)
        if Limit is not None:
            rows = rows[:Limit]
        if Select == "COUNT":
            return {"Count": len(rows)}
        return {"Items": rows}


@pytest.fixture
def cfake(monkeypatch):
    t = _CommentTable()
    # A and B are friends of the owner; "stranger" is not connected.
    friends = {"A": ["owner"], "B": ["owner"], "owner": ["A", "B"], "stranger": []}
    clock = {"t": 1000}

    def now_ms():
        clock["t"] += 1  # strictly increasing → deterministic thread ordering
        return clock["t"]

    monkeypatch.setattr(posts, "_posts", lambda: t)
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": uid, "name": uid.upper()})
    monkeypatch.setattr(posts, "_connected_ids", lambda uid: friends.get(uid, []))
    monkeypatch.setattr(posts, "_push", lambda *a, **k: None)
    monkeypatch.setattr(posts, "_now_ms", now_ms)
    monkeypatch.setattr(posts, "_now_s", lambda: 1)
    # The post everyone comments on (owner's), seeded so _find_post resolves it.
    t.put_item(Item={"pk": "feed#owner", "sk": "post#1#p1", "postId": "p1", "expiresAt": 10**12})
    return t


def _texts(listing):
    return [c["text"] for th in listing["threads"] for c in th["comments"]]


def test_comment_threads_are_private_per_commenter(cfake):
    """The spec example: A comments once, B comments once, owner replies to B
    once → owner sees 3, A sees 1, B sees 2; no one sees another's thread."""
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    posts.create_comment("B", {"postId": "p1", "postAuthorId": "owner", "text": "b1"})
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "re b", "threadUser": "B"}
    )

    owner_view = posts.list_comments("owner", {"postId": "p1", "postAuthorId": "owner"})
    assert owner_view["isOwner"] is True
    assert len(owner_view["threads"]) == 2
    assert sorted(_texts(owner_view)) == ["a1", "b1", "re b"]  # all 3

    a_view = posts.list_comments("A", {"postId": "p1", "postAuthorId": "owner"})
    assert a_view["isOwner"] is False
    assert len(a_view["threads"]) == 1
    assert _texts(a_view) == ["a1"]  # only A's own — never B's

    b_view = posts.list_comments("B", {"postId": "p1", "postAuthorId": "owner"})
    assert len(b_view["threads"]) == 1
    assert _texts(b_view) == ["b1", "re b"]  # their comment + owner's reply
    assert b_view["threads"][0]["comments"][1]["isOwner"] is True


def test_comment_count_matches_per_viewer_visibility(cfake):
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    posts.create_comment("B", {"postId": "p1", "postAuthorId": "owner", "text": "b1"})
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "re b", "threadUser": "B"}
    )
    assert posts._comment_count("p1", "owner", True) == 3
    assert posts._comment_count("p1", "A", False) == 1
    assert posts._comment_count("p1", "B", False) == 2
    assert posts._comment_count("p1", None, False) == 0  # signed-out feed


def test_friend_with_no_comment_sees_empty_not_others(cfake):
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    # B is a connected friend but hasn't commented → empty, NOT A's thread.
    b_view = posts.list_comments("B", {"postId": "p1", "postAuthorId": "owner"})
    assert b_view["threads"] == []


def test_owner_can_start_a_private_thread_by_mentioning_a_friend(cfake):
    # No threadUser (and not public) → the owner must choose someone.
    with pytest.raises(posts.ProxyError):
        posts.create_comment("owner", {"postId": "p1", "postAuthorId": "owner", "text": "hi"})
    # @-mentioning a CONNECTED friend who hasn't commented yet opens a fresh
    # private thread — only the owner + B can see it.
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "hi B", "threadUser": "B"}
    )
    b_view = posts.list_comments("B", {"postId": "p1", "postAuthorId": "owner"})
    assert _texts(b_view) == ["hi B"]
    assert b_view["threads"][0]["comments"][0]["isOwner"] is True
    # A different friend (A) must NOT see B's private thread.
    a_view = posts.list_comments("A", {"postId": "p1", "postAuthorId": "owner"})
    assert a_view["threads"] == []
    # But the owner can't open a private thread toward a NON-connected user.
    with pytest.raises(posts.ProxyError):
        posts.create_comment(
            "owner",
            {"postId": "p1", "postAuthorId": "owner", "text": "hi", "threadUser": "stranger"},
        )


def test_owner_mention_pushes_friend_then_reads_as_reply(cfake, monkeypatch):
    pushes = []
    monkeypatch.setattr(posts, "_push", lambda to, title, body="", data=None: pushes.append((to, title, data)))
    # Opening the thread via @-mention pings B as a mention…
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "hi B", "threadUser": "B"}
    )
    assert pushes[-1][0] == "B" and "mentioned you" in pushes[-1][1]
    # …carrying the deep-link route so a tap opens that post's comment thread.
    assert pushes[-1][2] == {"postId": "p1", "postAuthorId": "owner", "open": "comments"}
    # …and a follow-up into the now-existing thread reads as a reply.
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "again", "threadUser": "B"}
    )
    assert pushes[-1][0] == "B" and "replied to your comment" in pushes[-1][1]
    assert pushes[-1][2]["open"] == "comments"


def test_comment_notify_ok_reads_pref(monkeypatch):
    class _C:
        def __init__(self, item):
            self._item = item

        def get_item(self, Key=None):
            return {"Item": self._item} if self._item is not None else {}

    monkeypatch.setattr(posts, "_circle", lambda: _C(None))
    assert posts._comment_notify_ok("u") is True  # absent → on
    monkeypatch.setattr(posts, "_circle", lambda: _C({"comments": False}))
    assert posts._comment_notify_ok("u") is False  # explicitly muted
    monkeypatch.setattr(posts, "_circle", lambda: _C({"comments": True}))
    assert posts._comment_notify_ok("u") is True


def test_muted_recipient_gets_no_comment_push(cfake, monkeypatch):
    pushes = []
    monkeypatch.setattr(posts, "_push", lambda to, title, body="", data=None: pushes.append(to))
    # The owner muted comment notifications → a friend's comment doesn't push them…
    monkeypatch.setattr(posts, "_comment_notify_ok", lambda uid: uid != "owner")
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "hi"})
    assert "owner" not in pushes
    # …but the comment is still recorded, and an un-muted recipient (B) is pushed.
    assert posts._comment_count("p1", "owner", True) == 1
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "hey", "threadUser": "B"}
    )
    assert "B" in pushes


def test_non_friend_cannot_comment_or_view(cfake):
    with pytest.raises(posts.ProxyError):
        posts.create_comment("stranger", {"postId": "p1", "postAuthorId": "owner", "text": "hi"})
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    with pytest.raises(posts.ProxyError):
        posts.list_comments("stranger", {"postId": "p1", "postAuthorId": "owner"})


def test_comment_rejects_spoofed_owner_and_bad_input(cfake):
    with pytest.raises(posts.ProxyError):  # claim B owns the post → not found under B
        posts.create_comment("A", {"postId": "p1", "postAuthorId": "B", "text": "hi"})
    with pytest.raises(posts.ProxyError):  # empty text
        posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "  "})
    with pytest.raises(posts.ProxyError):  # missing postId
        posts.create_comment("A", {"postAuthorId": "owner", "text": "hi"})


def test_owner_can_delete_any_comment(cfake):
    a = posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    posts.create_comment("B", {"postId": "p1", "postAuthorId": "owner", "text": "b1"})
    assert posts.delete_comment(
        "owner",
        {"postId": "p1", "postAuthorId": "owner", "commentId": a["commentId"], "threadUser": "A"},
    ) == {"deleted": True}
    # A's thread is now empty; B's is untouched.
    assert posts._comment_count("p1", "A", False) == 0
    assert posts._comment_count("p1", "B", False) == 1
    assert posts._comment_count("p1", "owner", True) == 1


def test_commenter_deletes_own_comment_only(cfake):
    a = posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    reply = posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "re", "threadUser": "A"}
    )
    # A cannot delete the owner's reply…
    with pytest.raises(posts.ProxyError):
        posts.delete_comment(
            "A",
            {"postId": "p1", "postAuthorId": "owner", "commentId": reply["commentId"], "threadUser": "A"},
        )
    # …nor can a different user delete A's comment…
    with pytest.raises(posts.ProxyError):
        posts.delete_comment(
            "B",
            {"postId": "p1", "postAuthorId": "owner", "commentId": a["commentId"], "threadUser": "A"},
        )
    # …but A can delete their own.
    assert posts.delete_comment(
        "A",
        {"postId": "p1", "postAuthorId": "owner", "commentId": a["commentId"], "threadUser": "A"},
    )["deleted"] is True


def test_recent_comments_preview_is_per_viewer(cfake):
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    posts.create_comment("B", {"postId": "p1", "postAuthorId": "owner", "text": "b1"})
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "re b", "threadUser": "B"}
    )

    def texts(viewer, owner_view):
        return [
            posts._comment_preview(c)["text"]
            for c in posts._visible_comments("p1", viewer, owner_view)
        ]

    assert texts("owner", True) == ["a1", "b1", "re b"]  # owner: all, chronological
    assert texts("A", False) == ["a1"]  # A: only their own
    assert texts("B", False) == ["b1", "re b"]  # B: theirs + owner's reply
    assert posts._visible_comments("p1", None, False) == []  # signed out: none


def test_owner_public_comment_is_visible_to_everyone(cfake):
    # Owner broadcasts publicly; A comments privately; owner replies to A privately.
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "hello all", "public": True}
    )
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "hi A", "threadUser": "A"}
    )

    owner_view = posts.list_comments("owner", {"postId": "p1", "postAuthorId": "owner"})
    assert [c["text"] for c in owner_view["public"]] == ["hello all"]
    assert sum(len(t["comments"]) for t in owner_view["threads"]) == 2  # A's thread

    a_view = posts.list_comments("A", {"postId": "p1", "postAuthorId": "owner"})
    assert [c["text"] for c in a_view["public"]] == ["hello all"]  # sees the broadcast
    assert [c["text"] for t in a_view["threads"] for c in t["comments"]] == ["a1", "hi A"]

    # B is a friend who hasn't commented → public only, NO private thread.
    b_view = posts.list_comments("B", {"postId": "p1", "postAuthorId": "owner"})
    assert [c["text"] for c in b_view["public"]] == ["hello all"]
    assert b_view["threads"] == []


def test_non_owner_cannot_broadcast_public(cfake):
    # A is not the owner; even with public:true their comment stays PRIVATE.
    posts.create_comment(
        "A", {"postId": "p1", "postAuthorId": "owner", "text": "sneaky", "public": True}
    )
    b_view = posts.list_comments("B", {"postId": "p1", "postAuthorId": "owner"})
    assert b_view["public"] == []  # B never sees A's "public" attempt
    assert b_view["threads"] == []
    a_view = posts.list_comments("A", {"postId": "p1", "postAuthorId": "owner"})
    assert a_view["public"] == []
    assert [c["text"] for t in a_view["threads"] for c in t["comments"]] == ["sneaky"]


def test_visible_comments_includes_public(cfake):
    posts.create_comment(
        "owner", {"postId": "p1", "postAuthorId": "owner", "text": "pub", "public": True}
    )
    posts.create_comment("A", {"postId": "p1", "postAuthorId": "owner", "text": "a1"})

    def texts(viewer, owner_view):
        return sorted(
            posts._comment_preview(c)["text"]
            for c in posts._visible_comments("p1", viewer, owner_view)
        )

    assert texts("A", False) == ["a1", "pub"]  # commenter: public + own
    assert texts("B", False) == ["pub"]  # friend, no comment: public only
    assert texts(None, False) == ["pub"]  # signed-out: public only


def test_delete_missing_comment_404(cfake):
    with pytest.raises(posts.ProxyError):
        posts.delete_comment(
            "owner",
            {"postId": "p1", "postAuthorId": "owner", "commentId": "nope", "threadUser": "A"},
        )


# --- Eva surfaced in the feed (Roro's path untouched) ---

def test_feed_always_surfaces_eva(monkeypatch):
    """feed() folds the Eva account in for EVERY user, even when not connected —
    so her broadcasts reach everyone. Roro stays purely via _connected_ids."""
    monkeypatch.setattr(posts, "_connected_ids", lambda uid: ["roro-uid"])  # Roro via auto-follow
    monkeypatch.setattr(
        posts, "_account_uid", lambda h: "eva-uid" if h == posts.EVA_HANDLE else None
    )
    seen = []
    monkeypatch.setattr(posts, "_user_posts", lambda uid, viewer: seen.append(uid) or [])
    posts.feed("me")
    assert "me" in seen and "roro-uid" in seen and "eva-uid" in seen
    assert seen.count("eva-uid") == 1  # added once


def test_feed_never_doubles_eva_when_already_connected(monkeypatch):
    """If a user already follows Eva, she isn't added a second time (no dup)."""
    monkeypatch.setattr(posts, "_connected_ids", lambda uid: ["eva-uid"])
    monkeypatch.setattr(
        posts, "_account_uid", lambda h: "eva-uid" if h == posts.EVA_HANDLE else None
    )
    seen = []
    monkeypatch.setattr(posts, "_user_posts", lambda uid, viewer: seen.append(uid) or [])
    posts.feed("me")
    assert seen.count("eva-uid") == 1


# --- Official-account posting: the owner-only "push photo + text as Eva" path ---

def _official_stubs(monkeypatch, uid="eva-uid", name="Eva"):
    rows = []

    class _T:
        def put_item(self, Item=None):
            rows.append(Item)

    class _S3:
        def put_object(self, **kw):
            pass

    # _account_uid maps a handle → uid (None = unregistered).
    monkeypatch.setattr(posts, "_account_uid", lambda handle: uid)
    monkeypatch.setattr(posts, "_posts", lambda: _T())
    monkeypatch.setattr(posts, "_s3c", lambda: _S3())
    monkeypatch.setattr(posts, "_user_card", lambda u: {"handle": "eva", "name": name})
    monkeypatch.setattr(posts, "_now_ms", lambda: 1000)
    monkeypatch.setattr(posts, "_now_s", lambda: 1)
    return rows


def test_official_post_publishes_as_the_named_account(monkeypatch):
    rows = _official_stubs(monkeypatch, uid="eva-uid", name="Eva")
    img = base64.b64encode(b"\xff\xd8\xff\xffjpegbytes").decode()
    res = posts.official_post({"image": img, "text": "1.1.0 is live 🎉", "handle": "eva"})
    assert res["author"] == "Eva" and res["postId"] and res["handle"] == "eva"
    assert len(rows) == 1
    row = rows[0]
    assert row["pk"] == "feed#eva-uid"          # lands in EVA's feed (not roro's)
    assert row["authorName"] == "Eva"            # shows under the live account name
    assert row["name"] == "1.1.0 is live 🎉"     # text → caption
    assert row["photoKey"].startswith("posts/eva-uid/")
    assert row["expiresAt"] > 1                   # carries the standard TTL


def test_account_uid_resolves_and_normalizes_handle(monkeypatch):
    class _C:
        def get_item(self, Key=None):
            return {"Item": {"userId": "eva-uid"}} if Key["pk"] == "handle#eva" else {}

    monkeypatch.setattr(posts, "_circle", lambda: _C())
    assert posts._account_uid("@Eva") == "eva-uid"   # strips @, lowercases
    assert posts._account_uid("roro") is None         # unregistered → None


def test_official_post_rejects_missing_image(monkeypatch):
    _official_stubs(monkeypatch)
    with pytest.raises(posts.ProxyError):
        posts.official_post({"text": "no image", "handle": "eva"})


def test_official_post_404_when_account_missing(monkeypatch):
    _official_stubs(monkeypatch, uid=None)
    img = base64.b64encode(b"x").decode()
    with pytest.raises(posts.ProxyError):
        posts.official_post({"image": img, "text": "hi", "handle": "ghost"})


def test_official_post_route_requires_admin_token():
    # No x-admin-token → 403 at the handler, never reaching official_post.
    event = {
        "requestContext": {"http": {"method": "POST", "path": "/circle/official-post"}},
        "headers": {},
    }
    resp = posts.handler(event, None)
    assert resp["statusCode"] == 403
