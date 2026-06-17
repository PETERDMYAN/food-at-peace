import downloads

# Real DAILY SALES SUMMARY columns (the ones the parser reads must match Apple's).
HEADER = "\t".join([
    "Provider", "Provider Country", "SKU", "Developer", "Title", "Version",
    "Product Type Identifier", "Units", "Developer Proceeds", "Begin Date",
    "End Date", "Customer Currency", "Country Code", "Currency of Proceeds",
    "Apple Identifier",
])


def _row(pti, units, apple_id="6777715561"):
    return "\t".join([
        "APPLE", "US", "foodatpeace-001", "Dongming YAN", "Food at Peace", "1.0",
        pti, str(units), "0.00", "06/15/2026", "06/15/2026", "SGD", "SG", "SGD",
        apple_id,
    ])


def _tsv(*rows):
    return "\n".join([HEADER, *rows])


def test_counts_app_downloads_excluding_updates_and_iap():
    tsv = _tsv(
        _row("3F", 1),   # app download
        _row("1F", 2),   # app download
        _row("7F", 5),   # update -> excluded
        _row("IA1", 3),  # in-app purchase -> excluded
    )
    assert downloads.count_downloads(tsv, "6777715561") == 3


def test_filters_to_app_apple_id():
    tsv = _tsv(_row("1F", 4, "6777715561"), _row("1F", 9, "9999999999"))
    assert downloads.count_downloads(tsv, "6777715561") == 4
    assert downloads.count_downloads(tsv, "") == 13  # no filter -> both apps


def test_empty_header_only_and_none():
    assert downloads.count_downloads(None) == 0
    assert downloads.count_downloads("") == 0
    assert downloads.count_downloads(HEADER) == 0  # header, no data rows


def test_record_skips_zero_writes_positive(monkeypatch):
    calls = []

    class FakeTable:
        def update_item(self, **kw):
            calls.append(kw)

    monkeypatch.setattr(downloads, "_table", lambda: FakeTable())
    downloads._record("2026-06-15", 0)
    assert calls == []  # a 0-day adds nothing
    downloads._record("2026-06-15", 3)
    assert len(calls) == 1
    vals = calls[0]["ExpressionAttributeValues"]
    assert vals[":n"] == 3 and vals[":ds"] == "2026-06-15" and vals[":d"] == {"2026-06-15"}


def test_handler_counts_each_day_and_records(monkeypatch):
    monkeypatch.setattr(downloads, "_get_secret", lambda p: "p8")
    monkeypatch.setattr(downloads, "_asc_jwt", lambda p8, now: "jwt")
    monkeypatch.setattr(downloads, "_fetch_report", lambda token, d: _tsv(_row("1F", 2)))
    recorded = []
    monkeypatch.setattr(downloads, "_record", lambda d, n: recorded.append((d, n)))
    out = downloads.handler({"days": 3}, None)
    assert out["ok"] is True
    assert len(out["counted"]) == 3
    assert all(n == 2 for n in out["counted"].values())
    assert len(recorded) == 3
