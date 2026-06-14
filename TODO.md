# TODO — Food at Peace (`v2`)

Living todo list. Pre-ship stubs and device-verification items live in
[`QA_REPORT.md`](QA_REPORT.md) (§5–6).

## Backend topology (important)

Production 1.0.0 uses the prod proxy stack `food-at-peace-vision-proxy`
(API `6m19l2b025`). **v2 now points at a separate, isolated stack
`food-at-peace-vision-proxy-v2` (API `p21hoawoi5`)** — same SSM secrets, its own
resources — so v2 changes never touch production. Repointed in
[`dart_defines.json`](dart_defines.json). Deploy v2:
`cd backend && sam build && sam deploy --stack-name food-at-peace-vision-proxy-v2
--region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3
--no-confirm-changeset --parameter-overrides AppleClientId=com.foodatpeace.foodAtPeace`

---

## ✅ Done (reported by Peter)

### 1. AI analysis now follows the selected language ✅
When the app is in 中文 the photo estimate (name/items/portion/notes) comes back
in Chinese; English otherwise. Backward-compatible — no `lang` → English, so
production behaves identically.
- Client: [`claude_vision_client.dart`](lib/src/data/claude_vision_client.dart) (`languageDirective`),
  [`food_photo_analyzer.dart`](lib/src/data/food_photo_analyzer.dart) (sends `lang`),
  call site [`add_entry_screen.dart`](lib/src/features/add/add_entry_screen.dart).
- Backend: [`backend/src/app.py`](backend/src/app.py) (`language_directive`, accepts `lang`).
- Verified end-to-end against the live v2 endpoint (EN vs 中文, numbers unchanged).

### 2. Chinese (zh-Hans) App Store listing ✅
[`store/STORE_LISTING_zh.md`](store/STORE_LISTING_zh.md) — name/subtitle/promo/
description/keywords/what's-new, mirrors [`STORE_LISTING.md`](store/STORE_LISTING.md).

## ✅ Done (QA stub #3 — owner analytics)

### 3. Owner dashboard reads a real analytics backend ✅
New `POST /event` (open/scan/purchase/refund counters) + `GET /metrics`
([`backend/src/metrics.py`](backend/src/metrics.py), `MetricsTable`). App emits
`open` (launch) and `scan` (after analysis) via
[`analytics_service.dart`](lib/src/data/analytics_service.dart);
[`metrics_service.dart`](lib/src/data/metrics_service.dart) reads `/metrics`
(`isSample:false`), sample fallback when offline. Live-verified.
- Still needs external sources: **downloads** (App Store Connect API) and
  **revenue** (real IAP) — report 0 until those are wired (revenue ties to #5).

---

## ✅ Done (QA stub #4 — Circle of Food backend)

### 4. Circle of Food — real backend ✅
Real friend graph on the v2 stack: handle directory + invite/accept/decline/list
([backend/src/circle.py](backend/src/circle.py), `CircleTable`), with privacy-gated
trends computed read-only from a connected friend's own synced food + profile
(Mifflin target — never raw food). Client:
[circle_client.dart](lib/src/data/circle_client.dart) + `CircleNotifier` uses it
when signed in; the offline seeded mock is preserved for signed-out/tests.
Verified live with two minted users (invite → accept → connected-with-trend).
- **Signed-in path needs a real device** (Apple ID) to exercise end-to-end —
  same limitation as Sign in with Apple (QA §5).
- Follow-up: a handle-management screen (view/edit your own @handle). Today a
  handle is auto-derived from the profile name on first online use.

## 🚧 Remaining (QA stub §6)

### 5. Beans IAP — StoreKit + server receipt validation
Purchases/subscription are dev stubs (credit locally; reinstall resets).
Needs: `in_app_purchase` StoreKit flow, a backend `/iap/validate` endpoint
(Apple receipt / App Store Server API) that credits beans server-side, and
**App Store Connect IAP product creation + sandbox testing** (manual, external —
can't be done from here). Wire `purchase`/`refund` analytics events once live.

## 📱 Device-only verification (QA §5)
Sign in with Apple · Apple Health · local notifications · camera capture ·
weather chip — can't be automated on the simulator.
