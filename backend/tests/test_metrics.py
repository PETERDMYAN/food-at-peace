import pytest

import metrics


def test_last_7_days_is_oldest_to_newest():
    days = metrics._last_7_days("2026-06-14")
    assert days == [
        "2026-06-08", "2026-06-09", "2026-06-10", "2026-06-11",
        "2026-06-12", "2026-06-13", "2026-06-14",
    ]


def test_record_open_bumps_total_and_today(monkeypatch):
    writes = []
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: writes.append((pk, adds)))
    metrics.record_event({"type": "open"}, today="2026-06-14")
    assert ("counter", {"opensTotal": 1}) in writes
    assert ("day#2026-06-14", {"opens": 1}) in writes


def test_record_scan_bumps_photos(monkeypatch):
    writes = []
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: writes.append((pk, adds)))
    metrics.record_event({"type": "scan"})
    assert writes == [("counter", {"photosScanned": 1})]


def test_record_purchase_bumps_beans_and_revenue(monkeypatch):
    writes = []
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: writes.append((pk, adds)))
    metrics.record_event({"type": "purchase", "beans": 220, "amountCents": 499})
    assert writes == [("counter", {"beansSold": 220, "revenueCents": 499})]


def test_record_refund_bumps_count_and_amount(monkeypatch):
    writes = []
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: writes.append((pk, adds)))
    metrics.record_event({"type": "refund", "amountCents": 199})
    assert writes == [("counter", {"refunds": 1, "refundCents": 199})]


def test_record_unknown_event_rejected():
    with pytest.raises(metrics.ProxyError):
        metrics.record_event({"type": "definitely-not-a-real-event"})


# --- Auth: GET /metrics dual-token, POST /event app-token only ---------------

def _evt(method, headers, body=None):
    e = {"requestContext": {"http": {"method": method}}, "headers": headers}
    if body is not None:
        e["body"] = body
    return e


@pytest.fixture
def secrets(monkeypatch):
    """Stub the two SSM tokens; an unknown param raises (as the real fetch does)."""
    store = {
        metrics.APP_TOKEN_PARAM: "app-tok",
        metrics.METRICS_TOKEN_PARAM: "metrics-tok",
    }

    def fake(name):
        if name not in store:
            raise KeyError(name)
        return store[name]

    monkeypatch.setattr(metrics, "_get_secret", fake)
    return store


def test_get_metrics_accepts_dedicated_metrics_token(secrets, monkeypatch):
    monkeypatch.setattr(metrics, "build_metrics", lambda today=None: {"ok": True})
    resp = metrics.handler(_evt("GET", {"x-metrics-token": "metrics-tok"}), None)
    assert resp["statusCode"] == 200


def test_get_metrics_still_accepts_app_token_backcompat(secrets, monkeypatch):
    monkeypatch.setattr(metrics, "build_metrics", lambda today=None: {"ok": True})
    resp = metrics.handler(_evt("GET", {"x-app-token": "app-tok"}), None)
    assert resp["statusCode"] == 200


def test_get_metrics_rejects_wrong_or_missing_token(secrets):
    assert metrics.handler(_evt("GET", {"x-metrics-token": "nope"}), None)["statusCode"] == 401
    assert metrics.handler(_evt("GET", {}), None)["statusCode"] == 401


def test_event_write_rejects_readonly_metrics_token(secrets, monkeypatch):
    # The read-only dashboard token must never be able to emit events.
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: None)
    resp = metrics.handler(_evt("POST", {"x-metrics-token": "metrics-tok"}, '{"type":"open"}'), None)
    assert resp["statusCode"] == 401


def test_event_write_accepts_app_token(secrets, monkeypatch):
    writes = []
    monkeypatch.setattr(metrics, "_bump", lambda pk, adds: writes.append((pk, adds)))
    resp = metrics.handler(_evt("POST", {"x-app-token": "app-tok"}, '{"type":"scan"}'), None)
    assert resp["statusCode"] == 200
    assert writes == [("counter", {"photosScanned": 1})]


def test_ai_usage_token_weighted_and_call_hit_rates():
    ai = metrics._ai_usage({
        "aiCalls": 10, "aiCacheHitCalls": 8,
        "aiCacheReadTokens": 9000, "aiCacheWriteTokens": 1000,
        "aiInputTokens": 15000, "aiOutputTokens": 3000,
    })
    assert ai["calls"] == 10
    assert ai["cacheHitRate"] == 0.9          # 9000 / (9000 + 1000), token-weighted
    assert ai["cacheHitCallRate"] == 0.8      # 8 / 10 calls
    assert ai["inputTokens"] == 15000 and ai["outputTokens"] == 3000


def test_ai_usage_zero_safe_on_empty_counter():
    ai = metrics._ai_usage({})
    assert ai["calls"] == 0
    assert ai["cacheHitRate"] == 0.0 and ai["cacheHitCallRate"] == 0.0


def test_unprovisioned_metrics_token_denies(monkeypatch):
    # Before the SSM secret exists, presenting any metrics token must not work.
    def fake(name):
        if name == metrics.APP_TOKEN_PARAM:
            return "app-tok"
        raise KeyError(name)

    monkeypatch.setattr(metrics, "_get_secret", fake)
    resp = metrics.handler(_evt("GET", {"x-metrics-token": "anything"}), None)
    assert resp["statusCode"] == 401
