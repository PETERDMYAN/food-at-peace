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


def test_create_post_rejects_missing_and_oversized_image(monkeypatch):
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": None, "name": "X"})
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {})  # no image
    big = base64.b64encode(b"x" * (posts.MAX_IMAGE_BYTES + 10)).decode()
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {"image": big})  # too large
