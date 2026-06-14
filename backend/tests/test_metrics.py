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
