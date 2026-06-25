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


def test_feed_reactor_name_resolves_to_current_not_stale(monkeypatch):
    """A reaction freezes the reactor's name at react-time; the owner's feed must
    instead show the reactor's CURRENT circle name — so a friend who reacted
    before claiming a handle (stored 'Someone') no longer reads as 'Someone' once
    they have a name. Falls back to the stored value when there's no current one."""

    class _Q:
        def query(self, **kw):
            return {
                "Items": [
                    {"sk": "react#u_named", "emoji": "❤️", "reactorName": "Someone"},
                    {"sk": "react#u_blank", "emoji": "👍", "reactorName": "OldStored"},
                ]
            }

    names = {"u_named": "Eva"}  # u_blank has no current circle name

    class _Circle:
        def get_item(self, Key):
            uid = Key["pk"].split("#", 1)[1]
            return {"Item": {"name": names[uid]}} if uid in names else {}

    monkeypatch.setattr(posts, "_posts", lambda: _Q())
    monkeypatch.setattr(posts, "_circle", lambda: _Circle())

    _counts, _mine, reactors = posts._reactions_for("p1", "viewer1", True)
    by_emoji = {r["emoji"]: r["name"] for r in reactors}
    assert by_emoji["❤️"] == "Eva"  # current name, not the stale stored "Someone"
    assert by_emoji["👍"] == "OldStored"  # no current name → stored fallback


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


def test_official_feed_returns_official_account_posts(monkeypatch):
    """A signed-out viewer's official feed = the official @handle's own posts
    (looked up by handle), with no viewer (None) so it's the public view."""

    class _Circle:
        def get_item(self, Key):
            assert Key["pk"] == f"handle#{posts.OFFICIAL_HANDLE}"
            return {"Item": {"userId": "roro-uid"}}

    monkeypatch.setattr(posts, "_circle", lambda: _Circle())
    monkeypatch.setattr(
        posts,
        "_user_posts",
        lambda uid, viewer: [{"postId": "p1", "authorId": uid}]
        if (uid == "roro-uid" and viewer is None)
        else [],
    )
    out = posts.official_feed()
    assert out["posts"] == [{"postId": "p1", "authorId": "roro-uid"}]


def test_official_feed_empty_when_no_official_account(monkeypatch):
    class _Circle:
        def get_item(self, Key):
            return {}

    monkeypatch.setattr(posts, "_circle", lambda: _Circle())
    assert posts.official_feed() == {"posts": []}
