# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Food at Peace** is a Flutter (iOS-first) calorie & macro tracker: log food by hand or by
**photo** (Claude estimates the nutrition), track calorie/protein/saturated-fat targets against
Apple Health energy data, with accounts + cloud sync. Bilingual EN/中文. See `readme.md` for the
product tour and `TODO.md`/`QA_REPORT.md` for in-flight work.

Two halves live in one repo:
- **`lib/`** — the Flutter/Dart app.
- **`backend/`** — an AWS SAM (Python) stack of Lambdas: the Claude vision proxy plus
  auth/sync/account/metrics/circle endpoints.

## Commands

```bash
# Setup
flutter pub get
flutter gen-l10n                     # regenerate AppLocalizations from the .arb files (any build also does this)

# Run
flutter run -d chrome                # UI + manual logging only; no HealthKit / camera / native picker
cp dart_defines.example.json dart_defines.json   # fill in PROXY_BASE_URL + PROXY_APP_TOKEN (git-ignored)
flutter run -d ios --dart-define-from-file=dart_defines.json

# Checks & unit/widget tests (test/)
flutter analyze
flutter test
flutter test test/nutrition_math_test.dart        # a single test file
flutter test test/sync_merge_test.dart -n 'name'  # a single test by name

# Integration tests (integration_test/) — need a booted simulator/device, NOT run by `flutter test`
flutter test integration_test/qa_test.dart -d <device-id>
flutter test integration_test/lang_demo_test.dart -d <device-id> --dart-define-from-file=dart_defines.json  # hits the LIVE backend

# Backend (Python 3.13)
pytest backend/tests/                # no AWS/network — secrets stubbed, Anthropic mocked
pytest backend/tests/test_app.py     # a single backend test file
```

## ⚠️ Backend deploy topology — read before any `sam deploy`

There are **two isolated AWS stacks sharing the same SSM secrets**:
- **Production (1.0.0):** `food-at-peace-vision-proxy` — API `6m19l2b025`. **Never redeploy this for v2 work.**
- **v2 (current branch):** `food-at-peace-vision-proxy-v2` — API `p21hoawoi5`. `dart_defines.json` points here.

`backend/samconfig.toml`'s default `sam deploy` targets the **prod** stack name, so always pass the v2 name explicitly:

```bash
cd backend && sam build && sam deploy --stack-name food-at-peace-vision-proxy-v2 \
  --region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset \
  --parameter-overrides AppleClientId=com.foodatpeace.foodAtPeace
```

Secret setup (SSM Parameter Store, once per stack) and the full deploy story are in `backend/README.md`.

## 🔒 Never break the live production client↔server contract

The App Store-approved **1.0.0** app is in production against the prod proxy (`6m19l2b025`); installed copies can't be patched on demand, so treat that integration as **immutable**. Apply the **`production-safety` skill** (`.claude/skills/production-safety/SKILL.md`) before changing any backend endpoint, shared model, `dart_defines.json`, or deploy target. In short:

- Shared endpoints (`/analyze`, `/auth/apple`, `/sync`, `/account/delete`) stay **backward-compatible** — new request fields are OPTIONAL with the old behavior as the default (e.g. `lang` absent → English); never rename/remove/retype an existing field or change a status code's meaning. Add, don't alter.
- It's two-sided: before touching `food_photo_analyzer` / `claude_vision_client` / `sync_client` / `auth_client` (or the models they serialize), confirm the shipped app still works against the server, and vice-versa.
- Dev work targets the **v2** stack only; never redeploy prod or point a prod build at v2. If a change genuinely must reach prod, **stop and ask**.

## Architecture

**App layering:** `features/` (UI screens) → `providers/` (Riverpod state) → `data/` (services, repositories, API clients) → `models/`. Pure domain logic lives in `nutrition/` and the `DailySummary` model.

**`lib/src/providers/providers.dart` is the state hub** — nearly every provider is defined here. The pattern throughout: a `Notifier` reads initial state from a repository in `build()`, mutates `state`, and persists via that repository (which wraps `shared_preferences`). `sharedPreferencesProvider` throws by default and is **overridden in `main()`** with the loaded instance (and in tests with `SharedPreferences.setMockInitialValues`). When adding persisted state, follow this Notifier+repository shape rather than touching prefs from the UI.

**Photo analysis is a two-path abstraction** (`data/food_photo_analyzer.dart`):
- `foodPhotoAnalyzerProvider` returns `DirectAnalyzer` if the user saved their own Anthropic key (calls Anthropic directly via `ClaudeVisionClient`), else `ProxyAnalyzer` (the default — POSTs the photo to the AWS proxy, which holds the key server-side), else `null` (UI shows scanning unavailable).
- **The app ships no Claude key on the default path** — only a build-time `PROXY_BASE_URL` + revocable `PROXY_APP_TOKEN` (compile-time `String.fromEnvironment` constants in `providers.dart`, fed by `--dart-define-from-file`).
- **The Anthropic request (system prompt, `log_food` tool schema, prompt caching, language directive) is duplicated** in `data/claude_vision_client.dart` (Dart) and `backend/src/app.py` (Python). Change one → change the other, or the two paths diverge.

**Health integration uses a conditional import to keep `package:health` off web.** `data/health_service.dart` is an abstract interface; the implementation is picked at compile time via `import 'health_service_stub.dart' if (dart.library.io) 'health_service_io.dart'` — real HealthKit on mobile, a no-op stub on web. iOS never reveals read-authorization status, so the "connected" flag is remembered in prefs (`HealthConnectedNotifier`). Profile sex/age/height/weight are pulled from Health on launch/resume/connect/manual-sync but **manual edits are never clobbered** (`refreshFromHealth` honors `*ManuallySet` flags).

**Sync engine** (`data/sync_engine.dart`): best-effort bidirectional delta sync, **last-write-wins by `updatedAt`, tombstone-aware** (deletes are soft — `deleted:true` rows sync so entries don't resurrect). The merge is a pure, unit-tested `mergeById`. A per-user cursor tracks server time. `SyncEngine` debounces ~2s after local edits, also runs on sign-in/resume/manual button; `ref.keepAlive()` + HomeShell watching it keep its listeners live. It suspends itself during account deletion to avoid repopulating a deleting account.

**Targets engine is pure and unit-tested** (`nutrition/nutrition_math.dart` + `DailySummary.compute`): calorie budget = **full-day BMR (Mifflin-St Jeor) + measured active energy + goal gap**; protein = 1.6 g/kg; sat-fat cap = 10% of calorie target. Note `expenditure` (burn-so-far) is computed separately from the stable daily `calorieTarget`. Per-target manual overrides on the profile take precedence over computed values.

**Circle (the social layer) spans client + server in two parts.** The **friend graph** is `circleProvider`/`CircleNotifier` (claim a `@handle`, invite, accept; connected-friend trends) talking to `circle.py`. The **photo feed** is separate: `circleFeedProvider` (a `FutureProvider`) fetches via `PostsClient` (`data/posts_client.dart`) into the `CirclePost` model, rendered by `features/circle/circle_feed_screen.dart`; reactions are the fixed `circleReactionEmojis` set. **Posting is fire-and-forget on a successful photo scan-save** (`add_entry_screen.dart` → `_maybeShareToCircle`, with an opt-out toggle) — it never blocks the save or surfaces errors, and needs an account. Note the two photo sizes diverge: Claude gets a downscaled copy for faster analysis (`_downscaleForAnalysis`, via the `image` package), while the **full-resolution original** (HEIC-normalized to JPEG by `image_picker` at pick time) is what's retained and shared to the circle. The whole feed is a no-op when signed out or no proxy is configured. Server side is described under **Backend** below.

**Backend** — each route is its own Lambda handler under `backend/src/`, sharing:
- `common.py` — request/response/header parsing, `ProxyError`, and **SSM secret fetch cached per cold start** (`_secrets` dict; tests pre-populate it so no AWS call happens).
- `session.py` + `jwtlite.py` — HS256 app **session tokens**, pure stdlib (no PyJWT for our own tokens).
- Two auth models: the **`x-app-token`** (shared, ships in the app) gates `app.py` (vision) and `metrics.py`; a **Bearer session token** gates `sync.py`, `account.py`, `circle.py`, and `posts.py`. `auth.py` verifies the Apple identity token against Apple's JWKS (this one uses `PyJWT[crypto]`, bundled by `sam build`) and mints the session token.
- DynamoDB tables (`SyncTable`, `MetricsTable`, `CircleTable`, `PostsTable`), the S3 `CirclePhotosBucket`, and all routes are declared in `backend/template.yaml`. **Circle is two Lambdas:** `circle.py` is the friend graph (handle directory + mirrored friendship edges) plus read-only friend "trends" computed from a connected friend's own synced data — returned only as privacy-gated daily aggregates, never raw food. `posts.py` is the ephemeral photo feed (`/circle/post|feed|react`): a shared meal photo lives in S3 and a `PostsTable` row that **both self-expire after 3 days** (S3 lifecycle rule + DynamoDB TTL on `expiresAt`); the feed returns presigned S3 GET URLs and is privacy-gated to mutually-connected friends.

**Localization:** Flutter `gen-l10n`. Edit strings in `lib/l10n/app_en.arb` / `app_zh.arb` only — `lib/l10n/app_localizations*.dart` are **generated** (regenerated by `flutter gen-l10n` or any build); never hand-edit them. The app follows the system locale with a persisted manual override (`localeProvider`).

## Docs hygiene — update TODO.md + readme.md with every commit

Before any `git commit` / `git push`, update **`TODO.md`** (mark done items ✅, add new
follow-ups, bump the build/version line) and **`readme.md`** (refresh the `> **Status:**`
block — current TestFlight build, what's live, what's remaining), and stage them in the
**same commit** as the change. Apply the **`docs-before-commit` skill**
(`.claude/skills/docs-before-commit/SKILL.md`). Skip only for pure-docs or trivial
comment/typo edits — and say so.

## Gotchas

- **HealthKit needs a paid Apple Developer account** — a free Personal Team can't sign the `com.apple.developer.healthkit` entitlement, and free-team builds expire after 7 days.
- **Beans (in-app credit) and IAP/subscriptions are dev stubs** — balance is a local `shared_preferences` ledger; `purchasePack` credits locally. Production needs StoreKit + a server-side ledger with receipt validation (`TODO.md` §5).
- **Owner metrics**: `MetricsService` reads the live `/metrics` endpoint when a proxy is configured (`isSample:false`), with clearly-labelled sample data as the offline fallback. `downloads`/`revenue` stay 0 until App Store Connect API + real IAP are wired.
- Device-only flows (Sign in with Apple, Apple Health, local notifications, camera, weather GPS) **can't be exercised on the simulator** — integration tests stub them (e.g. `weatherProvider` → null, faked image picker).
