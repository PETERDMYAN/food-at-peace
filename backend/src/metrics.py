"""Food at Peace — owner analytics (AWS Lambda).

Two routes, both guarded by the shared app token (same one the vision proxy
uses):

* ``POST /event`` — the app emits lightweight, non-PII usage events
  (``open`` / ``scan`` / ``purchase`` / ``refund``). Each does an atomic
  DynamoDB ``ADD`` so counts are correct under concurrency.
* ``GET /metrics`` — the owner dashboard reads the aggregate counts back in the
  exact shape ``AppMetrics`` expects.

Counts live in one tiny table:

* ``pk = "counter"``            → lifetime totals (opens, scans, beans, revenue…)
* ``pk = "day#<YYYY-MM-DD>"``   → opens that day (for the 7-day sparkline + DAU)

``downloads`` needs the App Store Connect API and ``revenue`` only moves once
real IAP is wired, so those start at 0 — everything else is live.
"""

import datetime
import hmac
import os

from common import (
    ProxyError,
    _get_secret,
    _header,
    _parse_body,
    _response,
)

APP_TOKEN_PARAM = os.environ.get("APP_TOKEN_PARAM", "/food-at-peace/app-token")
METRICS_TABLE = os.environ.get("METRICS_TABLE", "")

_COUNTER_PK = "counter"
_ddb = None


def _table():
    global _ddb
    if _ddb is None:
        import boto3  # lazy: keeps the module importable without boto3 in tests

        _ddb = boto3.resource("dynamodb").Table(METRICS_TABLE)
    return _ddb


def _authorize(event):
    provided = _header(event, "x-app-token")
    expected = _get_secret(APP_TOKEN_PARAM)
    if not provided or not hmac.compare_digest(provided, expected):
        raise ProxyError(401, "Not authorized.")


def _today(now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y-%m-%d")


def _last_7_days(today=None):
    """Oldest → newest list of the last 7 calendar dates (UTC)."""
    base = (
        datetime.datetime.strptime(today, "%Y-%m-%d")
        if today
        else datetime.datetime.now(datetime.timezone.utc)
    )
    return [(base - datetime.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]


def _bump(pk, adds):
    """Atomically ADD the given integer deltas onto one item."""
    names = {f"#{k}": k for k in adds}
    values = {f":{k}": v for k, v in adds.items()}
    expr = "ADD " + ", ".join(f"#{k} :{k}" for k in adds)
    _table().update_item(
        Key={"pk": pk},
        UpdateExpression=expr,
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )


# --- Event ingestion ---------------------------------------------------------

def record_event(body, today=None):
    """Apply one event to the counters. Pure dispatch over [body] → list of
    (pk, {field: delta}) writes; returns the writes so it's unit-testable."""
    etype = body.get("type")
    today = today or _today()
    writes = []
    if etype == "open":
        writes.append((_COUNTER_PK, {"opensTotal": 1}))
        writes.append((f"day#{today}", {"opens": 1}))
    elif etype == "scan":
        writes.append((_COUNTER_PK, {"photosScanned": 1}))
    elif etype == "purchase":
        beans = int(body.get("beans") or 0)
        cents = int(body.get("amountCents") or 0)
        writes.append((_COUNTER_PK, {"beansSold": beans, "revenueCents": cents}))
    elif etype == "refund":
        cents = int(body.get("amountCents") or 0)
        writes.append((_COUNTER_PK, {"refunds": 1, "refundCents": cents}))
    else:
        raise ProxyError(400, "Unknown event type.")
    for pk, adds in writes:
        _bump(pk, adds)
    return writes


# --- Aggregation -------------------------------------------------------------

def _get_int(pk, field):
    item = _table().get_item(Key={"pk": pk}).get("Item") or {}
    return int(item.get(field, 0) or 0)


def build_metrics(today=None):
    days = _last_7_days(today)
    counter = _table().get_item(Key={"pk": _COUNTER_PK}).get("Item") or {}
    opens7d = [_get_int(f"day#{d}", "opens") for d in days]
    return {
        # Needs the App Store Connect API — not wired yet, so reported as 0.
        "downloads": 0,
        "activeToday": opens7d[-1],
        "opensTotal": int(counter.get("opensTotal", 0) or 0),
        "opens7d": opens7d,
        "photosScanned": int(counter.get("photosScanned", 0) or 0),
        "beansSold": int(counter.get("beansSold", 0) or 0),
        "revenueSgd": int(counter.get("revenueCents", 0) or 0) / 100.0,
        "refunds": int(counter.get("refunds", 0) or 0),
        "refundSgd": int(counter.get("refundCents", 0) or 0) / 100.0,
        # Live data (not the in-app placeholder set).
        "isSample": False,
    }


def handler(event, context):
    try:
        _authorize(event)
        method = (event.get("requestContext", {}).get("http", {}).get("method") or "").upper()
        if method == "GET":
            return _response(200, build_metrics())
        record_event(_parse_body(event))
        return _response(200, {"ok": True})
    except ProxyError as exc:
        return _response(exc.status, {"error": {"message": exc.message}})
    except Exception:  # noqa: BLE001 — never leak internals to the client
        return _response(500, {"error": {"message": "Unexpected error."}})
