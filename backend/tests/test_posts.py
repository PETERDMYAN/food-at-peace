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


def test_create_post_rejects_missing_and_oversized_image(monkeypatch):
    monkeypatch.setattr(posts, "_user_card", lambda uid: {"handle": None, "name": "X"})
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {})  # no image
    big = base64.b64encode(b"x" * (posts.MAX_IMAGE_BYTES + 10)).decode()
    with pytest.raises(posts.ProxyError):
        posts.create_post("u1", {"image": big})  # too large
