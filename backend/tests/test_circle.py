import pytest

import circle


def test_normalize_handle_ok():
    assert circle.normalize_handle("@Alex") == "alex"
    assert circle.normalize_handle("  mia_99 ") == "mia_99"


def test_normalize_handle_rejects_bad():
    for bad in ["", "a", "@", "has space", "waaaaytoolonghandle_over20", "bad-dash"]:
        with pytest.raises(circle.ProxyError):
            circle.normalize_handle(bad)


def test_set_notify_prefs_writes_row(monkeypatch):
    saved = {}

    class _C:
        def put_item(self, Item=None):
            saved.clear()
            saved.update(Item)

    monkeypatch.setattr(circle, "_circle", lambda: _C())
    # Explicit off is stored as comments=False on the user's prefs row.
    assert circle.set_notify_prefs("u1", {"comments": False}) == {"comments": False}
    assert saved == {"pk": "user#u1", "sk": "notifyprefs", "comments": False}
    # Absent → ON (backward-compatible default).
    assert circle.set_notify_prefs("u1", {}) == {"comments": True}
    assert saved["comments"] is True


def test_compute_target_uses_override():
    assert circle.compute_target({"calorieGoalOverride": 2222}) == 2222.0


def test_compute_target_mifflin_male_moderate_maintain():
    # 10*80 + 6.25*180 - 5*30 + 5 = 1780 BMR; *1.55 = 2759
    p = {"weightKg": 80, "heightCm": 180, "age": 30, "sex": "male",
         "activity": "moderate", "goal": "maintain"}
    assert round(circle.compute_target(p)) == 2759


def test_compute_target_female_sedentary_lose():
    p = {"weightKg": 60, "heightCm": 165, "age": 28, "sex": "female",
         "activity": "sedentary", "goal": "lose"}
    assert round(circle.compute_target(p)) == round((10 * 60 + 6.25 * 165 - 5 * 28 - 161) * 1.2 - 500)


def test_compute_target_unusable_returns_zero():
    assert circle.compute_target({}) == 0.0
    assert circle.compute_target(None) == 0.0


def test_build_trend_buckets_by_day_streak_and_adherence():
    profile = {"calorieGoalOverride": 2000}
    food = [
        {"calories": 500, "timestamp": "2026-06-14T08:00:00.000"},
        {"calories": 700, "timestamp": "2026-06-14T19:00:00.000"},
        {"calories": 1000, "timestamp": "2026-06-13T12:00:00.000"},
        {"calories": 300, "timestamp": "2026-06-01T12:00:00.000"},  # outside the 7-day window
    ]
    tr = circle.build_trend(profile, food, today="2026-06-14")
    assert tr["target"] == 2000
    assert tr["kcal"] == 1200  # today's total
    assert tr["adh"][-1] == 60  # 1200 / 2000
    assert tr["adh"][-2] == 50  # 1000 / 2000 on the 13th
    assert len(tr["adh"]) == 7
    assert tr["streak"] == 2  # 13th + 14th logged, 12th empty


def test_build_trend_no_target_gives_zero_adherence():
    tr = circle.build_trend(
        {}, [{"calories": 500, "timestamp": "2026-06-14T08:00:00"}], today="2026-06-14"
    )
    assert tr["target"] == 0
    assert tr["adh"][-1] == 0
    assert tr["kcal"] == 500


# --- connect (one-tap mutual connect via an invite link/QR) ------------------

class FakeCircleTable:
    """In-memory stand-in for the CircleTable resource (pk+sk composite key)."""

    def __init__(self):
        self.items = {}

    def get_item(self, Key):
        item = self.items.get((Key["pk"], Key["sk"]))
        return {"Item": dict(item)} if item else {}

    def put_item(self, Item):
        self.items[(Item["pk"], Item["sk"])] = dict(Item)

    def delete_item(self, Key):
        self.items.pop((Key["pk"], Key["sk"]), None)

    def update_item(self, Key, UpdateExpression, ExpressionAttributeNames=None,
                    ExpressionAttributeValues=None):
        # Minimal SET support: "SET #a = :x, b = :y".
        item = self.items.setdefault((Key["pk"], Key["sk"]), dict(Key))
        names = ExpressionAttributeNames or {}
        vals = ExpressionAttributeValues or {}
        body = UpdateExpression.strip()[len("SET "):]
        for assign in body.split(","):
            lhs, rhs = (s.strip() for s in assign.split("="))
            item[names.get(lhs, lhs)] = vals[rhs.strip()]

    def query(self, KeyConditionExpression=None, **kw):
        # Minimal support for `pk = <v> AND begins_with(sk, <prefix>)`.
        pk_val, sk_prefix = None, ""

        def walk(cond):
            nonlocal pk_val, sk_prefix
            expr = cond.get_expression()
            op, vals = expr["operator"], expr["values"]
            if op == "AND":
                for v in vals:
                    walk(v)
            elif op == "=" and getattr(vals[0], "name", None) == "pk":
                pk_val = vals[1]
            elif op == "begins_with" and getattr(vals[0], "name", None) == "sk":
                sk_prefix = vals[1]

        walk(KeyConditionExpression)
        return {
            "Items": [
                dict(v)
                for (pk, sk), v in self.items.items()
                if pk == pk_val and sk.startswith(sk_prefix)
            ]
        }


@pytest.fixture
def circle_table(monkeypatch):
    fake = FakeCircleTable()
    monkeypatch.setattr(circle, "_circle", lambda: fake)
    return fake


def _edge(table, owner, other):
    return table.items.get((f"user#{owner}", f"friend#{other}"))


def test_connect_makes_both_sides_connected(circle_table):
    circle.register("u_a", {"handle": "alex", "name": "Alex"})
    circle.register("u_b", {"handle": "mia", "name": "Mia"})

    # B opens A's invite link (https://…/i/alex) -> taps connect.
    out = circle.connect("u_b", {"handle": "@alex"})
    assert out == {"status": "connected", "handle": "@alex", "name": "Alex"}

    assert _edge(circle_table, "u_b", "u_a")["status"] == "connected"
    assert _edge(circle_table, "u_a", "u_b")["status"] == "connected"
    # Mirrored edges carry the *other* person's handle/name.
    assert _edge(circle_table, "u_b", "u_a")["handle"] == "@alex"
    assert _edge(circle_table, "u_a", "u_b")["handle"] == "@mia"


def test_connect_is_idempotent(circle_table):
    circle.register("u_a", {"handle": "alex"})
    circle.register("u_b", {"handle": "mia"})
    circle.connect("u_b", {"handle": "alex"})
    # A second tap (e.g. the link re-opened) just stays connected.
    out = circle.connect("u_b", {"handle": "alex"})
    assert out["status"] == "connected"
    assert _edge(circle_table, "u_b", "u_a")["status"] == "connected"
    assert _edge(circle_table, "u_a", "u_b")["status"] == "connected"


def test_connect_upgrades_a_pending_invite(circle_table):
    circle.register("u_a", {"handle": "alex"})
    circle.register("u_b", {"handle": "mia"})
    # A had already invited B (pending), then B taps A's link.
    circle.invite("u_a", {"handle": "mia"})
    assert _edge(circle_table, "u_b", "u_a")["status"] == "incoming"
    circle.connect("u_b", {"handle": "alex"})
    assert _edge(circle_table, "u_b", "u_a")["status"] == "connected"
    assert _edge(circle_table, "u_a", "u_b")["status"] == "connected"


def test_connect_requires_a_claimed_handle(circle_table):
    circle.register("u_a", {"handle": "alex"})
    with pytest.raises(circle.ProxyError) as e:
        circle.connect("u_b", {"handle": "alex"})  # B never registered
    assert e.value.status == 400


def test_connect_rejects_unknown_handle(circle_table):
    circle.register("u_b", {"handle": "mia"})
    with pytest.raises(circle.ProxyError) as e:
        circle.connect("u_b", {"handle": "ghost"})
    assert e.value.status == 404


def test_connect_rejects_self(circle_table):
    circle.register("u_a", {"handle": "alex"})
    with pytest.raises(circle.ProxyError) as e:
        circle.connect("u_a", {"handle": "alex"})
    assert e.value.status == 400


# --- name-drift: the friend list serves each friend's *live* me-card name -----
def test_list_circle_serves_live_name_after_a_rename(circle_table):
    # A invites B -> B has an incoming request from A, name cached as "Alex".
    circle.register("u_a", {"handle": "alex", "name": "Alex"})
    circle.register("u_b", {"handle": "mia", "name": "Mia"})
    circle.invite("u_a", {"handle": "mia"})
    assert _edge(circle_table, "u_b", "u_a")["name"] == "Alex"  # cached at invite

    # A renames by re-registering the SAME handle with a new name. The name
    # cached on the edge is now stale...
    circle.register("u_a", {"handle": "alex", "name": "Alex Rivera"})
    assert _edge(circle_table, "u_b", "u_a")["name"] == "Alex"
    # ...but B's circle list serves A's *live* me-card name instead.
    out = circle.list_circle("u_b")
    assert out["incoming"][0]["name"] == "Alex Rivera"


# --- follow the creator (@roro): request -> Roro accepts -> mutual friends ----


def test_follow_roro_request_then_accept_makes_friends(circle_table, monkeypatch):
    """The scenario: a user follows @roro, Roro accepts, they become friends."""
    # Accept fires a best-effort APNs push (needs creds) — stub it for the test.
    monkeypatch.setattr(circle, "_push", lambda *a, **k: None)

    circle.register("u_roro", {"handle": "roro", "name": "Roro"})  # creator account
    circle.register("u_user", {"handle": "foodie", "name": "Foodie"})

    # 1) The user follows Roro -> a request is sent (outgoing for them, incoming for Roro).
    out = circle.invite("u_user", {"handle": "roro"})
    assert out["status"] == "outgoing"
    assert _edge(circle_table, "u_user", "u_roro")["status"] == "outgoing"
    assert _edge(circle_table, "u_roro", "u_user")["status"] == "incoming"

    # 2) Roro accepts the request.
    out = circle.respond("u_roro", {"userId": "u_user", "action": "accept"})
    assert out["status"] == "connected"

    # 3) They are now mutual friends in the food circle.
    assert _edge(circle_table, "u_user", "u_roro")["status"] == "connected"
    assert _edge(circle_table, "u_roro", "u_user")["status"] == "connected"
    assert _edge(circle_table, "u_user", "u_roro")["handle"] == "@roro"
    assert _edge(circle_table, "u_roro", "u_user")["handle"] == "@foodie"
    # No dangling request remains on the user's side.
    assert _edge(circle_table, "u_user", "u_roro")["status"] != "outgoing"


def test_follow_roro_one_tap_connect_makes_friends(circle_table):
    """The app's current Follow button: one-tap connect (instant, no accept)."""
    circle.register("u_roro", {"handle": "roro", "name": "Roro"})
    circle.register("u_user", {"handle": "foodie", "name": "Foodie"})
    out = circle.connect("u_user", {"handle": "roro"})
    assert out["status"] == "connected"
    assert _edge(circle_table, "u_user", "u_roro")["status"] == "connected"
    assert _edge(circle_table, "u_roro", "u_user")["status"] == "connected"
