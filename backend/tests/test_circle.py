import pytest

import circle


def test_normalize_handle_ok():
    assert circle.normalize_handle("@Alex") == "alex"
    assert circle.normalize_handle("  mia_99 ") == "mia_99"


def test_normalize_handle_rejects_bad():
    for bad in ["", "a", "@", "has space", "waaaaytoolonghandle_over20", "bad-dash"]:
        with pytest.raises(circle.ProxyError):
            circle.normalize_handle(bad)


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
