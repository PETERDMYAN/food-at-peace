"""Food at Peace — App Store Connect downloads sync (scheduled AWS Lambda).

Daily, pull the App Store Connect **Sales & Trends** report and fold first-time
app downloads into the owner-metrics ``downloads`` counter — idempotently per
report date, so re-runs (and the overlapping look-back window) never double-count.

* Downloads = sum of ``Units`` for the app, EXCLUDING updates (Product Type
  Identifier ``7*``) and in-app purchases / subscriptions (``IA*``).
* The ES256 JWT is signed with the pure-Python ``ecdsa`` lib (no native crypto
  wheel), exactly like ``apns.py``.
* Key id / issuer / vendor number / app Apple id are non-secret config (env);
  only the ``.p8`` private key is an SSM SecureString.

Invoke with ``{"days": N}`` to back-fill the last N report dates (default 3);
the daily schedule keeps it current.
"""

import base64
import csv
import datetime
import gzip
import hashlib
import io
import json
import os
import time
import urllib.error
import urllib.request

from common import _get_secret

ASC_KEY_ID = os.environ.get("ASC_KEY_ID", "")
ASC_ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
ASC_VENDOR_NUMBER = os.environ.get("ASC_VENDOR_NUMBER", "")
ASC_APPLE_ID = os.environ.get("ASC_APPLE_ID", "")
ASC_KEY_PARAM = os.environ.get("ASC_KEY_PARAM", "/food-at-peace/asc-private-key")
METRICS_TABLE = os.environ.get("METRICS_TABLE", "")

_API = "https://api.appstoreconnect.apple.com/v1/salesReports"
_ddb = None


def _table():
    global _ddb
    if _ddb is None:
        import boto3  # lazy: keeps the module importable in tests without boto3

        _ddb = boto3.resource("dynamodb").Table(METRICS_TABLE)
    return _ddb


def _b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _asc_jwt(p8, now):
    """ES256 App Store Connect token (≤20 min), signed with the .p8 via ecdsa."""
    import ecdsa  # pure-Python ES256 signing (same as apns.py)

    header = _b64(
        json.dumps({"alg": "ES256", "kid": ASC_KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode()
    )
    payload = _b64(
        json.dumps(
            {"iss": ASC_ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode("ascii")
    sk = ecdsa.SigningKey.from_pem(p8)
    sig = sk.sign_deterministic(
        signing_input, hashfunc=hashlib.sha256, sigencode=ecdsa.util.sigencode_string
    )  # JWS ES256 = raw r||s
    return f"{header}.{payload}.{_b64(sig)}"


def _fetch_report(token, report_date):
    """The DAILY SALES SUMMARY TSV for a date, or None when no report exists (404)."""
    url = (
        f"{_API}?filter[frequency]=DAILY&filter[reportType]=SALES"
        f"&filter[reportSubType]=SUMMARY&filter[vendorNumber]={ASC_VENDOR_NUMBER}"
        f"&filter[version]=1_0&filter[reportDate]={report_date}"
    )
    req = urllib.request.Request(
        url, headers={"Authorization": f"Bearer {token}", "Accept": "application/a-gzip"}
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:  # noqa: S310 (Apple URL)
            return gzip.GzipFile(fileobj=io.BytesIO(r.read())).read().decode("utf-8")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None  # no sales finalised for that day
        raise


def count_downloads(tsv, apple_id=""):
    """First-time app-download Units: drop updates (PTI ``7*``) and in-app
    purchases (``IA*``); optionally match the app's Apple Identifier. Pure."""
    if not tsv:
        return 0
    total = 0
    for row in csv.DictReader(io.StringIO(tsv), delimiter="\t"):
        pti = (row.get("Product Type Identifier") or "").strip().upper()
        if pti.startswith("7") or pti.startswith("IA"):
            continue
        if apple_id and (row.get("Apple Identifier") or "").strip() != str(apple_id):
            continue
        try:
            total += int(float(row.get("Units") or 0))
        except (ValueError, TypeError):
            pass
    return total


def _record(report_date, downloads):
    """Fold one day's downloads into the cumulative counter, exactly once per date
    (a string-set of processed dates makes re-runs a no-op via the condition)."""
    if downloads <= 0:
        return  # nothing to add; a 0-day stays refetchable (cheap, bounded window)
    try:
        _table().update_item(
            Key={"pk": "counter"},
            UpdateExpression="ADD downloads :n, processedSalesDates :d",
            ConditionExpression=(
                "attribute_not_exists(processedSalesDates) "
                "OR NOT contains(processedSalesDates, :ds)"
            ),
            ExpressionAttributeValues={":n": downloads, ":d": {report_date}, ":ds": report_date},
        )
    except Exception:  # noqa: BLE001 — ConditionalCheckFailed = date already counted
        pass


def handler(event, context):
    days = int((event or {}).get("days") or 3)
    p8 = _get_secret(ASC_KEY_PARAM)
    token = _asc_jwt(p8, int(time.time()))
    today = datetime.datetime.now(datetime.timezone.utc).date()
    counted = {}
    # Reports lag ~1 day; walk a small window so a missed run self-heals.
    for back in range(1, days + 1):
        d = (today - datetime.timedelta(days=back)).isoformat()
        try:
            tsv = _fetch_report(token, d)
        except Exception:  # noqa: BLE001 — one bad day shouldn't sink the run
            continue
        n = count_downloads(tsv, ASC_APPLE_ID)
        counted[d] = n
        _record(d, n)
    return {"ok": True, "counted": counted}
