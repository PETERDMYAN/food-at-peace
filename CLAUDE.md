# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Food at Peace** is a Flutter (iOS-first) calorie & macro tracker: log food by hand or by
**photo** (Claude estimates the nutrition), track calorie/protein/saturated-fat targets against
Apple Health energy data, with accounts + cloud sync. Bilingual EN/中文. See `readme.md` for the
product tour **and its `> **Status:**` block — the single source of truth for which build is live
on the App Store / in review (don't trust a build number quoted anywhere else, including this
file)**; `TODO.md`/`QA_REPORT.md` for in-flight work; `PUBLISHING.md` for the iOS App Store
release runbook (Xcode signing → archive → upload); `GOOGLE_SIGNIN.md` for the designed-but-unbuilt
Google sign-in (blocked on a Google OAuth client — nothing is implemented); and
`GARMIN_INTEGRATION.md` for the planned-but-blocked direct-Garmin path.

Three surfaces live in one repo:
- **`lib/`** — the Flutter/Dart app (iOS-first; also builds for web/Android).
- **`backend/`** — an AWS SAM (Python) stack of Lambdas: the Claude vision proxy plus
  auth / sync / account / metrics / circle / posts / **beans + IAP + Stripe recharge** /
  durable meal-photo / APNs endpoints.
- **`store/website/`** — a static site on S3 + CloudFront (`foodatpeace.app`, distribution
  `E2M22G0LAT1HKW`, bucket `foodatpeace-app-web`): marketing/landing pages plus *live*
  destinations — **`/recharge`** (Stripe Beans top-up, Sign in with Apple in the browser; see
  `store/RECHARGE.md`), **`/dashboard`** (owner metrics) and **`/admin`** (owner console: paste
  the admin token → grant Beans / post as Eva; `store/website/admin/`) — and the `/i` invite
  landing + Apple App Site Association for universal links (`store/INVITE_LINKS.md`). A
  CloudFront Function (`store/cloudfront-functions/fap-rewrite-index.js`, deployed by hand with
  `aws cloudfront update-function` + `publish-function`) rewrites `/`-terminated and bare paths
  to their `index.html`. The rest of `store/` is App Store listing copy + screenshot assets.

## Commands

```bash
# Setup
flutter pub get
flutter gen-l10n                     # regenerate AppLocalizations from the .arb files (any build also does this)
dart run flutter_launcher_icons      # only after changing assets/icon/app_icon.png

# Run
flutter run -d chrome                # UI + manual logging only; no HealthKit / camera / native picker
cp dart_defines.example.json dart_defines.json   # fill in PROXY_BASE_URL + PROXY_APP_TOKEN (git-ignored)
flutter run -d ios --dart-define-from-file=dart_defines.json

# Checks & unit/widget tests (test/)
flutter analyze
flutter test
flutter test test/nutrition_math_test.dart        # a single test file
flutter test test/sync_merge_test.dart -n 'name'  # a single test by name

# Integration tests (integration_test/) — need a booted simulator/device, NOT run by `flutter test`.
# Only qa_test.dart is a real test suite; most other files there are demo / screenshot DRIVERS
# (*_demo.dart, *_shots.dart, *_tour.dart) that seed a simulator for videos and store assets.
flutter test integration_test/qa_test.dart -d <device-id>
flutter test integration_test/lang_demo_test.dart -d <device-id> --dart-define-from-file=dart_defines.json  # hits the LIVE backend
flutter test integration_test/store_screenshots.dart -d <udid> --dart-define=LOCALE=en   # App Store shots — store/SCREENSHOTS.md

# Backend (Python 3.13)
pytest backend/tests/                # no AWS/network — secrets stubbed, Anthropic mocked
pytest backend/tests/test_app.py     # a single backend test file

# Website — publish ADDITIVELY (never `sync --delete`; see the bare-key gotcha at the bottom)
aws s3 cp store/website/recharge/index.html s3://foodatpeace-app-web/recharge/index.html --content-type "text/html; charset=utf-8"
aws cloudfront create-invalidation --distribution-id E2M22G0LAT1HKW --paths '/recharge' '/recharge/*'
```

## ⚠️ Backend deploy topology — read before any `sam deploy`

There are **two isolated AWS stacks sharing the same SSM secrets**:
- **Production:** `food-at-peace-vision-proxy` — API `6m19l2b025`. Backs the **live App Store
  build** (release tags `v1.0.0` … `v1.1.1` — `git tag -l`; what's live vs. in review is in
  `readme.md`'s Status block) and carries the full backend (Circle incl. comments + official posts /
  Beans / IAP / Metrics / Posts / recharge / meal-photos / APNs). **Never redeploy this for
  in-progress dev work** — only deliberate release cutovers, with a changeset preview.
- **v2 (dev / simulator stack):** `food-at-peace-vision-proxy-v2` — API `p21hoawoi5`.
  `dart_defines.json` points here. (The repo is a single `main` plus release branches like
  `1.0.2`; **"v2" is the *stack* name, not a branch.**)

> **⚠️ Build target ↔ which `dart_defines` (gets data right):** the **main app**
> (`com.foodatpeace.foodAtPeace`) — every TestFlight build the **real user** installs
> **and** every App Store submission — MUST build with
> `--dart-define-from-file=dart_defines.prod.json` (**prod** `6m19l2b025`, where the
> real user data lives). `dart_defines.json` (**v2** `p21hoawoi5`) is **dev / simulator
> testing only**. Building the **main** app against
> v2 makes a returning user's data look **blank** (their rows are on prod). Prod already
> runs the full migrated feature set, so a current client works against it. (Memory:
> `dart-defines-prod-vs-v2`.)

`backend/samconfig.toml`'s default `sam deploy` targets the **prod** stack name, so always pass the v2 name explicitly:

```bash
cd backend && sam build && sam deploy --stack-name food-at-peace-vision-proxy-v2 \
  --region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset \
  --parameter-overrides 'AppleClientId="com.foodatpeace.foodAtPeace,com.foodatpeace.web"'
```

**Every deploy of either stack must keep the two-audience `AppleClientId`** (native bundle id +
the web Services ID `com.foodatpeace.web`): a deploy that passes only the native id silently
clobbers it and breaks Sign in with Apple on `/recharge` (v2 drifted that way once). Secret setup
(SSM Parameter Store, once per stack) and the full deploy story are in `backend/README.md`.

## 🔒 Never break the live production client↔server contract

The App Store app runs against the prod proxy (`6m19l2b025`); installed copies can't be patched on demand, so treat that integration as **immutable**. Whatever the current store build is, the original **1.0.0** contract is the floor (not every user has updated) — stay compatible with the oldest still-installed client. Apply the **`production-safety` skill** (`.claude/skills/production-safety/SKILL.md`) before changing any backend endpoint, shared model, `dart_defines.json`, or deploy target. In short:

- The endpoints the **1.0.0** client calls (`/analyze`, `/auth/apple`, `/sync`, `/account/delete`) stay **backward-compatible** — new request fields are OPTIONAL with the old behavior as the default (e.g. `lang` absent → English); never rename/remove/retype an existing field or change a status code's meaning. Add, don't alter. The same rule extends to every endpoint a *shipped* build relies on (`/circle/*`, the `/posts` feed, `/beans`, `/iap/validate`, `/photo/*`, `/recharge/*`) — they're just as un-patchable in the wild.
- It's two-sided: before touching any API client (`food_photo_analyzer` / `claude_vision_client` / `sync_client` / `auth_client` / `circle_client` / `posts_client` / `beans_client` / `meal_photo_store`) or the models they serialize, confirm the shipped app still works against the server, and vice-versa.
- Dev work targets the **v2** stack only; never redeploy prod or point a prod build at v2. If a change genuinely must reach prod, **stop and ask**.

## Project skills (`.claude/skills/`) — apply without being asked

Each one is a checklist written after something went wrong once:
- **`production-safety`** — before any backend endpoint / shared model / API client / `dart_defines` / deploy-target change, or a push to `main` (above).
- **`verify-in-simulator`** — after ANY change under `lib/` and before calling it done or shipping a build: run it on the iOS simulator and confirm it looks right *and* works (Today data + meal photos load, a brand-new user can onboard, reach the Circle and see Eva + Roro, follow/unfollow works). Fix, then re-verify.
- **`docs-before-commit`** — before every commit/push (section below).
- **`ship-feature`** / **`new-user-experience`** — shipping a user-facing feature (actual before/after pictures, one pair per feature) / checking the first-run path.
- **`no-dummy-data`** — `lib/` renders honest empty states; demo/seed content lives ONLY in `integration_test/` + `test/` via provider overrides or mock prefs (seeded fake friends once shipped to real users — an App Store rejection risk).
- **`circle-comments-privacy`** — before touching comment endpoints, models, providers or the comments sheet (detail under Circle below).
- **`demo-names`** (Eva is the primary demo person, Peter the second) and **`video-to-drive`** (any generated video gets hosted + linked in the user's Drive).

## Architecture

**App layering:** `features/` (UI screens) → `providers/` (Riverpod state) → `data/` (services, repositories, API clients) → `models/`, plus shared `theme/`, `widgets/`, and `util/` cutting across. Pure domain logic lives in `nutrition/` and the `DailySummary` model. Notable feature areas: `features/home/` (`HomeShell` — the tab shell, also where push deep-links land), `features/today/`, `features/add/`, `features/circle/`, `features/trends/`, `features/sources/` (data-source priority), `features/wallet/` (Beans), `features/onboarding/`, `features/settings/`, `features/feedback/`.

**`lib/src/providers/providers.dart` is the state hub** — nearly every provider is defined here. The pattern throughout: a `Notifier` reads initial state from a repository in `build()`, mutates `state`, and persists via that repository (which wraps `shared_preferences`). `sharedPreferencesProvider` throws by default and is **overridden in `main()`** with the loaded instance (and in tests with `SharedPreferences.setMockInitialValues`). When adding persisted state, follow this Notifier+repository shape rather than touching prefs from the UI.

**Photo analysis is a two-path abstraction** (`data/food_photo_analyzer.dart`):
- `foodPhotoAnalyzerProvider` returns `DirectAnalyzer` if the user saved their own Anthropic key (calls Anthropic directly via `ClaudeVisionClient`), else `ProxyAnalyzer` (the default — POSTs the photo to the AWS proxy, which holds the key server-side), else `null` (UI shows scanning unavailable).
- **The app ships no Claude key on the default path** — only a build-time `PROXY_BASE_URL` + revocable `PROXY_APP_TOKEN` (compile-time `String.fromEnvironment` constants in `providers.dart`, fed by `--dart-define-from-file`).
- **The Anthropic request (system prompt, `log_food` tool schema, prompt caching, language directive) is duplicated** in `data/claude_vision_client.dart` (Dart) and `backend/src/app.py` (Python). Change one → change the other, or the two paths diverge.

**Health integration uses a conditional import to keep `package:health` off web.** `data/health_service.dart` is an abstract interface; the implementation is picked at compile time via `import 'health_service_stub.dart' if (dart.library.io) 'health_service_io.dart'` — real HealthKit on mobile, a no-op stub on web. iOS never reveals read-authorization status, so the "connected" flag is remembered in prefs (`HealthConnectedNotifier`). Profile sex/age/height/weight are pulled from Health on launch/resume/connect/manual-sync but **manual edits are never clobbered** (`refreshFromHealth` honors `*ManuallySet` flags). **Measured active energy can come from more than one device**, so a user-ordered priority (`energySourcePriorityProvider`; UI in `features/sources/` + `features/settings/data_sources_screen.dart`) decides which source feeds the targets engine and prevents double-counting — the same seam a direct Garmin integration would plug into.

**Sync engine** (`data/sync_engine.dart`): best-effort bidirectional delta sync, **last-write-wins by `updatedAt`, tombstone-aware** (deletes are soft — `deleted:true` rows sync so entries don't resurrect). The merge is a pure, unit-tested `mergeById`. A per-user cursor tracks server time. `SyncEngine` debounces ~2s after local edits, also runs on sign-in/resume/manual button; `ref.keepAlive()` + HomeShell watching it keep its listeners live. It suspends itself during account deletion to avoid repopulating a deleting account.

**Identity is the raw Apple `sub` — there is no account record.** `user_id = "apple:" + sub` is used *directly* as the partition key for Sync, Beans and Circle (`@handle`, friend edges, profile photo all key off it), so an account's id can never change; a second identity provider has to *alias* to it (the design in `GOOGLE_SIGNIN.md`). Session tokens (`AuthNotifier` ← `data/session_store.dart`) are HS256 JWTs minted for `SessionTtlDays` (template parameter → `SESSION_TTL_DAYS`, 365 since 1.1.3; was 60) and **renewed by `POST /auth/refresh`**: `AuthNotifier.refreshIfDue` re-mints a token older than 7 days on launch/resume, so an active user never expires; only a definitive 401 signs them out — and raises `sessionExpiredNoticeProvider` → `SessionExpiredBanner`. The refresh honours the account-deletion revocation marker (`minIat`) like `/sync` does. See the session-expiry gotcha below.

**Targets engine is pure and unit-tested** (`nutrition/nutrition_math.dart` + `DailySummary.compute`): calorie budget = **full-day BMR (Mifflin-St Jeor) + measured active energy + goal gap**; protein = 1.6 g/kg; sat-fat cap = 10% of calorie target. Note `expenditure` (burn-so-far) is computed separately from the stable daily `calorieTarget`. Per-target manual overrides on the profile take precedence over computed values.

**Circle (the social layer) spans client + server in two parts.** The **friend graph** is `circleProvider`/`CircleNotifier` (claim a `@handle`, invite, accept; connected-friend trends) talking to `circle.py`. The **photo feed** is separate: `circleFeedProvider` (a `FutureProvider`) fetches via `PostsClient` (`data/posts_client.dart`) into the `CirclePost` model, rendered by `features/circle/circle_feed_screen.dart`; reactions are the fixed `circleReactionEmojis` set. **Posting is fire-and-forget on a successful photo scan-save** (`add_entry_screen.dart` → `_maybeShareToCircle`, with an opt-out toggle) — it never blocks the save or surfaces errors, and needs an account (silently skipped when signed out). Note the two photo sizes diverge: Claude and the Circle post get a downscaled copy (`_downscaleForAnalysis`, via the `image` package), while the **full-resolution original** (HEIC-normalized to JPEG by `image_picker` at pick time) is what's retained in the durable meal-photo store. Signed out, the feed falls back to the **official feed** — the same `GET /circle/feed` sent with the app token but no Bearer session, which `posts.py` answers with `official_feed()` (Roro + Eva's posts) — so a brand-new user still sees real photos; with no proxy configured the whole feed is a no-op. Server side is described under **Backend** below. Three more Circle layers ride on the feed:
- **Comments are PRIVATE per-commenter threads with the post owner as the hub** — the owner sees every thread and replies into each (or broadcasts a public comment under the `__public__` sentinel); a commenter sees only their own thread. Client: `CircleComment*` models in `circle_post.dart`, `PostsClient.comment|comments|deleteComment`, `postCommentsProvider`, `_CommentsSheet` + inline `recentComments` preview in `circle_feed_screen.dart`; `commentCount` is per-viewer. **Read the `circle-comments-privacy` skill before touching any of it.**
- **Official accounts:** `@roro` and `@eva` are DISTINCT server-side accounts surfaced to every feed (Roro via auto-follow, Eva appended server-side); `kRoroHandle`/`kEvaHandle`/`isOfficialHandle` (providers.dart) drive the `OfficialBadge`. The owner posts as them via `backend/scripts/official_post.py` (→ admin-token-gated `POST /circle/official-post`) or the web `/admin` console. Eva also has a purely **client-side** face — the daily wisdom / story lessons in `data/eva_wisdom.dart` + `assets/eva_wisdom.json` — unrelated to the `@eva` server account; don't conflate the two.
- **Push deep-linking:** APNs payloads carry `{postId, postAuthorId, open}` route keys (`posts.py _route` → `apns.py`); native taps cross the `app.foodatpeace/notifications` method channel (`AppDelegate.swift`, incl. cold start) → `NotificationRouter` → `pendingDeepLinkProvider` → HomeShell switches to Circle and `CircleFeedBody` opens the post/comment sheet. Tap-routing is device-only (can't be exercised on the simulator).

**Meal photos have two independent stores — don't conflate them.** The **durable** one holds the user's own full-res originals: `data/meal_photo_store.dart` ↔ `backend/src/mealphotos.py` (`/photo/*`) keep them in S3 with **no expiry** and re-download them via presigned URLs, so a reinstall restores the Food story / archive (the synced `photoThumb` on the entry is just a small offline preview, not the original). The **ephemeral** one is the Circle feed above — a *shared* copy in `CirclePhotosBucket` that self-expires after 30 days (was 3 until 1.1.2). Same source photo, two lifecycles.

**Beans & payments span client + server.** `data/beans_client.dart` ↔ `backend/src/beans.py` are a server-side **append-only ledger** (`/beans`, idempotent by txn id, merges like sync so the balance follows the account across devices); the local `shared_preferences` ledger is just the offline cache. Credits appear **only after server-side verification**: `data/iap_service.dart` drives real StoreKit consumables (`in_app_purchase`) that `iap.py` validates against Apple's receipt API, and the web `/recharge` page is a no-Apple-cut **Stripe** path (`recharge.py`, signed webhook) into the *same* ledger. Both recompute the bean amount from `productId` server-side (client-supplied amounts are never trusted) and fall back to a local credit only when their secret is unconfigured. `recharge.py`'s `PRODUCTS` map is **append-only** (delist a pack from the page's `PACKS` array, never from `PRODUCTS` — cached pages and late webhooks still reference old ids). **Per App Store Guideline 3.1.1 the app never links out to `/recharge`** — in-app buying stays on StoreKit. The in-app Beans UI (balance + buy) is `features/wallet/beans_screen.dart`.

**Backend** — each route is its own Lambda handler under `backend/src/`, sharing:
- `common.py` — request/response/header parsing, `ProxyError`, and **SSM secret fetch cached per cold start** (`_secrets` dict; tests pre-populate it so no AWS call happens). Handlers don't log requests: a 4xx `ProxyError` leaves no CloudWatch trace, so "no errors in the logs" only rules out crashes.
- `session.py` + `jwtlite.py` — HS256 app **session tokens**, pure stdlib (no PyJWT for our own tokens).
- Two auth models (plus two owner tokens): the **`x-app-token`** (shared, ships in the app) gates `app.py` (vision), `metrics.py` (which also accepts **`x-metrics-token`** so the web `/dashboard` never holds the app token) and the official feed; a **Bearer session token** gates `sync.py`, `account.py`, `circle.py`, `posts.py`, `beans.py`, `iap.py`, `mealphotos.py`, and `recharge.py`'s `/checkout`. Owner-only endpoints (`POST /beans/grant`, `POST /circle/official-post`) take **`x-admin-token`** (SSM `/food-at-peace/admin-token`). `recharge.py`'s `/webhook` is *unauthenticated* but **HMAC-verified** against Stripe's `Stripe-Signature`. `auth.py` verifies the Apple identity token against Apple's JWKS (this one uses `PyJWT[crypto]`, bundled by `sam build`) and mints the session token — its accepted-audience list (`APPLE_CLIENT_ID`, comma-separated) holds **both** the native bundle id and the web Services ID `com.foodatpeace.web`, so Sign in with Apple lands on the same account in the app and on `/recharge`.
- DynamoDB tables (`SyncTable`, `MetricsTable`, `CircleTable`, `PostsTable`, `BeansTable`), the S3 buckets `CirclePhotosBucket` (ephemeral, 30-day TTL) + `MealPhotosBucket` (durable), and all routes are declared in `backend/template.yaml`. **Circle is two Lambdas:** `circle.py` is the friend graph (handle directory + mirrored friendship edges) plus read-only friend "trends" computed from a connected friend's own synced data — returned only as privacy-gated daily aggregates, never raw food. `posts.py` is the ephemeral photo feed plus comments and official posts (`/circle/post|feed|react|comment|comments|comment/delete|notify-prefs|official-post`; `GET /circle/feed` without a Bearer session but with the app token returns the public official feed): a shared meal photo lives in S3 and a `PostsTable` row (comments/reactions ride the same table) that **all self-expire after 30 days** — one `TTL_SECONDS` constant + the S3 lifecycle rule + DynamoDB TTL on `expiresAt`; the feed returns presigned S3 GET URLs (6-h validity, independent of storage TTL) and is privacy-gated to mutually-connected friends. Comment pushes honor the per-user `/circle/notify-prefs` row (`_comment_notify_ok`).
- **Payments:** `beans.py` (server ledger) + `iap.py` (validate Apple receipt → credit) + `recharge.py` (Stripe Checkout + signed webhook → credit; `/recharge/handle` resolves an `@handle` so a top-up can target *another* user as a "deposit address"). Stripe is hand-rolled (`urllib` + `hmac`), so nothing is added to `requirements.txt`.
- **Best-effort extras:** `apns.py` sends APNs alerts (ES256 signed via the pure-Python `ecdsa` lib — no Docker needed for `sam build`; device tokens are registered through `/circle/register-device` and stored in `CircleTable`). `downloads.py` is a **scheduled** (`rate(1 day)`) Lambda that folds App Store Connect Sales & Trends into the owner-metrics `downloads` counter, idempotently per report date. `mealphotos.py` is the durable per-user photo store described under **Architecture** above.

**Localization:** Flutter `gen-l10n`. Edit strings in `lib/l10n/app_en.arb` / `app_zh.arb` only — `lib/l10n/app_localizations*.dart` are **generated** (regenerated by `flutter gen-l10n` or any build); never hand-edit them. The app follows the system locale with a persisted manual override (`localeProvider`).

## Docs hygiene — update TODO.md + readme.md with every commit

Before any `git commit` / `git push`, update **`TODO.md`** (mark done items ✅, add new
follow-ups, bump the build/version line) and **`readme.md`** (refresh the `> **Status:**`
block — current TestFlight build, what's live, what's remaining), and stage them in the
**same commit** as the change. Apply the **`docs-before-commit` skill**
(`.claude/skills/docs-before-commit/SKILL.md`). Skip only for pure-docs or trivial
comment/typo edits — and say so.

## Gotchas

- **Session expiry looks like a broken server.** On 2026-08-30 every June sign-in hit the then-60-day hard expiry at once; clients ≤ 1.1.2 drop an expired token *silently* (`AuthNotifier._load` deletes it, `SyncEngine` signs out on 401), and a signed-out app still scans photos (that path uses the app token) but **quietly stops syncing, uploading full-res meal photos, and sharing to the Circle** (`_maybeShareToCircle` returns early) while the Circle shows only the official feed. 1.1.3 added weekly renewal (`/auth/refresh`, TTL 365) and the "Your sign-in expired" card, but users on older builds can still go dark this way. First check for "my photo doesn't show in the Circle" / "is the server down?": Settings → is the user still signed in? Re-signing in restores everything (all data is keyed by the stable Apple `sub`). Diagnose from AWS with read-only calls (CloudWatch `Errors`/`4xx`, `AuthFunction` invocations = sign-in dates, a `PostsTable` scan) before suspecting the stack.
- **HealthKit needs a paid Apple Developer account** — a free Personal Team can't sign the `com.apple.developer.healthkit` entitlement, and free-team builds expire after 7 days.
- **Garmin is HealthKit-only today** — a Garmin watch reaches the app only by syncing to Apple Health (the app reads active energy from HealthKit). There is **no direct Garmin API integration yet**; the `garmin` strings/comments in `lib/` are UI labels + placeholders for a planned OAuth path that is **blocked on Garmin partner approval** (`GARMIN_INTEGRATION.md`). Don't assume a Garmin client/Lambda exists.
- **Beans are server-backed now, not a stub** — a server-side append-only ledger (`beans.py` / `beans_client.dart`) that merges like sync, fed by **validated** purchases: real StoreKit IAP (`iap_service.dart` → `iap.py`, Apple-receipt-checked) and the web Stripe `/recharge` page. The local `shared_preferences` ledger is only the offline cache; `iap.py`/`recharge.py` fall back to a local credit just when their secret is unconfigured. (Live on Stripe as of 2026-06-23; the 25-bean pack is S$0.50, Stripe's SGD minimum.)
- **Owner metrics**: `MetricsService` reads the live `/metrics` endpoint when a proxy is configured (`isSample:false`), with clearly-labelled sample data as the offline fallback. `downloads` is populated by the scheduled `downloads.py` (App Store Connect Sales & Trends) and `revenue` by validated IAP/Stripe purchases — both go live once the ASC keys + Stripe live keys are in SSM. The same numbers also render on the web `/dashboard`.
- **Website bare-key objects.** S3's index document only serves `/recharge/` (trailing slash); the advertised `/recharge`, `/dashboard` (and `/admin`) also rely on a *bare* S3 object of the same name (`aws s3 cp store/website/recharge/index.html s3://foodatpeace-app-web/recharge`) that has no counterpart in `store/website/` — so `aws s3 sync … --delete` wipes them. Publish additively and invalidate the specific paths.
- Device-only flows (Sign in with Apple, Apple Health, local notifications, camera, weather GPS) **can't be exercised on the simulator** — integration tests stub them (e.g. `weatherProvider` → null, faked image picker).
