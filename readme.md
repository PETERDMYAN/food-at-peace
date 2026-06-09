# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat — by hand
or by **snapping a photo** — see how much you can still eat today, and keep an eye
on your protein and saturated-fat quotas. Connects to **Apple Health / Garmin**
for real calories burned, and speaks **English and 中文**. Built with Flutter.

> **Status:** Runs on-device on iPhone (paid Apple Developer membership active) with a
> redesigned high-contrast UI. Complete: manual + photo logging, the targets engine,
> Apple Health/Garmin, EN/中文, weight log, feedback, a Trends screen, and **accounts +
> cloud sync** — Sign in with Apple → an AWS Lambda + DynamoDB backend (the Claude key
> stays server-side; no secret ships in the app).
> Next up: Google sign-in, subscriptions, and targets polish.

## What it does today
- **Today dashboard** — calories left for the day (progress ring) plus protein and
  saturated-fat quota cards. Shows your *measured* burn when Apple Health is
  connected, and a card of today's workouts.
- **Add food** — manual entry, or **scan a meal photo** and let Claude estimate the
  calories / protein / saturated fat for you to confirm.
- **Weight log** — record your weight; it updates your profile and writes back to
  Apple Health.
- **History** — entries grouped by day with daily calorie totals.
- **Settings** — profile (sex, age, height, weight, activity, goal) with a live
  target preview, language switch, Claude key, Apple Health/Garmin connection, and
  a feedback link.
- **Apple Health / Garmin** — reads active + resting energy, latest weight, and
  workouts; writes logged food + weight back. Garmin data flows in via Apple Health.
- **Bilingual** — English / 中文, following the iOS system language with a manual
  override in Settings.
- **Theme** — a GXS-style purple Material 3 palette.
- **Feedback** — an in-app form that submits to a Google Form.

## How the targets work
- **Calorie budget:** a full day's resting energy (Mifflin-St Jeor BMR) + the
  active energy you've burned (measured via Apple Health, or 0 when it isn't
  connected) + the goal adjustment (lose -500, maintain 0, gain +400). When Health
  isn't connected the resting + active part is replaced by BMR × activity
  multiplier. Calories left = budget - eaten. The budget stays stable through the
  day so you can plan meals against it.
- **Burn** (shown beneath the budget) is your *actual* expenditure so far today —
  measured resting + active energy from Apple Health — so it climbs as the day goes
  on, independent of the budget.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

## Photo analysis (Claude)
Photos are analyzed via Anthropic's Messages API, forcing a `log_food` tool for
structured output (name / calories / protein / saturated fat / portion / confidence).
The Claude key lives **server-side** in an AWS Lambda proxy (see
[`backend/`](backend/README.md)) — the app ships no key. Which path runs depends on
Settings:
1. if the user pastes their **own** key in **Settings** (stored in the iOS Keychain),
   the app calls Anthropic directly with it (`ClaudeVisionClient` via `DirectAnalyzer`);
2. otherwise the app calls the proxy (`ProxyAnalyzer`), sending only the photo + a
   build-time app token (`--dart-define=PROXY_BASE_URL` / `PROXY_APP_TOKEN`).

The proxy is defined with AWS SAM (Python); deploy + secret setup are in
[`backend/README.md`](backend/README.md).

## Localization
Uses Flutter `gen-l10n`. Strings live in `lib/l10n/app_en.arb` and `app_zh.arb`; run
`flutter gen-l10n` (or any build) to regenerate `AppLocalizations`. The app follows
the system locale by default and persists a manual choice.

## Status & remaining work

**Done (in `main`):**
- [x] Manual food logging + targets engine
- [x] Apple Health "calories out" — active + resting energy
- [x] Claude photo analysis
- [x] Health expansion — read weight + workouts, write food + weight back
- [x] High-contrast GXS-violet redesign — dark + light, modern type, floating cards
- [x] English / 中文 localization (follows the system language, with a manual toggle)
- [x] Manual weight log
- [x] In-app feedback → Google Form
- [x] Deploy to iPhone (paid Apple Developer membership active)
- [x] AWS Lambda vision proxy holds the Claude key server-side (SAM + Python, in
  `backend/`); the app ships no key
- [x] Accounts + sync **backend** — Sign in with Apple (`/auth/apple` → app session
  token) + DynamoDB delta sync (`/sync`), deployed to `ap-southeast-1`
- [x] Accounts + sync **app side** — Sign in with Apple UI + auth state, and
  bidirectional sync of food / weight / profile (last-write-wins, tombstone deletes);
  triggers on sign-in / resume / edit / manual. Verified pushing to DynamoDB on device.
- [x] Trends screen (charts)

**TODO:**
- [ ] **Targets polish** — show the calorie target as a goal *gap* (±) with edit-all,
  auto-fill age / height / weight from Apple Health, and drop the manual weight log
- [ ] **Google Sign-In** — fast-follow: `/auth/google` mirroring `/auth/apple`
- [ ] **Subscriptions** — SGD 1.99/month (auto-renew) + SGD 3.99 / 100-day
  (non-renewing) via StoreKit IAP, with server-side receipt validation
- [ ] Confirm the exact GXS purple shade
- [ ] Later: home-screen widget, reminders, barcode scan, Android

## Tech stack
- **Flutter / Dart**, iOS first (iPhone), then Android and web.
- **Riverpod** for state; **shared_preferences** for local data (behind repositories)
  and **flutter_secure_storage** for the API key; **http**, **image_picker**, the
  **health** package, **intl** + **flutter_localizations**.

## Getting started
```bash
flutter pub get
flutter gen-l10n          # generate the localization classes

# Browser (UI + manual logging; no HealthKit / camera):
flutter run -d chrome

# iOS device (uses the AWS proxy for photo analysis):
cp dart_defines.example.json dart_defines.json   # then add PROXY_BASE_URL + PROXY_APP_TOKEN
flutter run -d ios --dart-define-from-file=dart_defines.json
```
`dart_defines.json` is git-ignored. Deploy the proxy first ([`backend/`](backend/README.md)),
or skip it and paste your own Anthropic key in the app's **Settings** to analyze photos
via the direct path.

### Tests & checks
```bash
flutter analyze
flutter test
```

## iOS notes
- **HealthKit needs a paid Apple Developer Program account.** A free Personal Team
  cannot sign the `com.apple.developer.healthkit` entitlement, so the health
  features only build on a paid team. Apps signed with a free team also expire after
  7 days (a paid team lasts a year).
- Built with **Xcode 26.5+** (matching recent macOS).

## Project layout
```
lib/
  main.dart                 app entry (loads storage, sets up Riverpod)
  app.dart                  MaterialApp + theme + localization
  l10n/                     app_en.arb / app_zh.arb + generated AppLocalizations
  src/
    models/                 FoodEntry, UserProfile, DailySummary, EnergyOut,
                            WorkoutSummary, WeightEntry, MealType, FoodAnalysis
    nutrition/              NutritionMath (BMR, TDEE, targets)
    data/                   Food/Profile/Weight repositories, ApiKeyStore,
                            ClaudeVisionClient + FoodPhotoAnalyzer (proxy/direct),
                            HealthService (+io/stub), FeedbackService
    providers/              Riverpod providers
    features/               today / add / history / settings / feedback screens
    theme/ util/            theme, formatting, localized enum labels
test/                       unit + widget tests
ios/                        Runner + Runner.entitlements (HealthKit)
backend/                    AWS SAM vision proxy (Lambda, Python) — holds the Claude key
```
