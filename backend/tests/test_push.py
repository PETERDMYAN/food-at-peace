import pytest

import apns
import circle


class FakeCircle:
    def __init__(self):
        self.items = {}

    def put_item(self, Item):
        self.items[(Item["pk"], Item["sk"])] = dict(Item)

    def get_item(self, Key):
        it = self.items.get((Key["pk"], Key["sk"]))
        return {"Item": dict(it)} if it else {}

    def query(self, KeyConditionExpression=None, **kw):
        # Test stand-in: return the device# rows (device_tokens only needs those).
        return {
            "Items": [v for (_pk, sk), v in self.items.items() if sk.startswith("device#")]
        }


@pytest.fixture
def circle_table(monkeypatch):
    fake = FakeCircle()
    monkeypatch.setattr(circle, "_circle", lambda: fake)
    return fake


def test_register_device_stores_token(circle_table):
    assert circle.register_device("u1", {"token": "tok-abc"}) == {"status": "registered"}
    assert ("user#u1", "device#tok-abc") in circle_table.items


def test_register_device_rejects_empty(circle_table):
    with pytest.raises(circle.ProxyError):
        circle.register_device("u1", {"token": ""})


def test_apns_device_tokens_lists_registered(circle_table):
    circle.register_device("u1", {"token": "t1"})
    circle.register_device("u1", {"token": "t2"})
    assert set(apns.device_tokens(circle_table, "u1")) == {"t1", "t2"}


def test_apns_send_is_noop_without_tokens():
    # Empty token list returns immediately — no network, never raises.
    apns.send(lambda name: "secret", [], "title", "body")


def test_circle_push_never_raises_when_apns_unconfigured(circle_table):
    # _push wraps apns; with no APNS_TEAM_ID/tokens it must be a silent no-op so
    # the invite/accept flows never break on a push failure.
    circle._push("u1", "hello")


def test_register_device_stores_lang(circle_table):
    circle.register_device("u1", {"token": "tok-zh", "lang": "zh"})
    assert circle_table.items[("user#u1", "device#tok-zh")]["lang"] == "zh"


def test_register_device_without_lang_omits_it(circle_table):
    # Old clients don't send lang → the row simply has none (no crash, defaults en).
    circle.register_device("u1", {"token": "tok-plain"})
    assert "lang" not in circle_table.items[("user#u1", "device#tok-plain")]


def test_user_lang_reads_from_device_then_defaults(circle_table):
    assert apns.user_lang(circle_table, "u1") == "en"  # no devices → default
    circle.register_device("u1", {"token": "t1", "lang": "zh"})
    assert apns.user_lang(circle_table, "u1") == "zh"
