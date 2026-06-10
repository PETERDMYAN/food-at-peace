# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat — by hand
or by **snapping a photo** — see how much you can still eat today, and keep an eye
on your protein and saturated-fat quotas. Connects to **Apple Health / Garmin**
for real calories burned, and speaks **English and 中文**. Built with Flutter.

> **Status:** Runs on-device on iPhone (paid Apple Developer membership active) with a
> dark, GXS-style UI. Complete: first-run onboarding, manual + photo logging, the
> goal-**gap** targets engine, Apple Health/Garmin (auto-fills age/height/weight), an
> interactive Trends screen, a local **weather** header, EN/中文, feedback, and
> **accounts + cloud sync** — Sign in with Apple → an AWS Lambda + DynamoDB backend
> (the Claude key stays server-side; no secret ships in the app).
> Next up: Google sign-in and subscriptions.

## What it does today
- **Onboarding** — on first launch: continue with **Sign in with Apple** (pulls your
  name) or type it, pick a goal, and connect Apple Health. Anything you skip shows up
  as a "Finish setting up" checklist on Today.
- **Today dashboard** — a large time-of-day greeting ("Good evening, …" with an emoji)
  and your local **weather** (animated background reflecting rain/sun/cloud/snow +
  a temperature/condition chip; falls back to an approximate IP location if you
  decline GPS). A calorie ring (budget = burn + your calorie *gap*),
  protein and saturated-fat cards, and a card of today's workouts.
- **Add food** — manual entry, or **scan a meal photo** and let Claude estimate the
  calories / protein / saturated fat for you to confirm.
- **Trends** — daily charts for calories / protein / saturated fat vs. target, each
  led by a prominent "on target X/Y days" stat. Switch between **1 / 7 / 30-day**
  windows, page to earlier windows with prev/next, and tap or drag a chart to read
  any day's value against the target.
- **Settings** — profile (age / height / weight, synced from Apple Health and editable
  via a pen — edits write height + weight back to Health), editable targets (calorie
  gap, protein, saturated-fat cap), account & sync, Apple Health connection, language,
  and feedback.
- **Apple Health / Garmin** — reads active + resting energy, weight, height, and date
  of birth (→ age), plus workouts; writes logged food, weight, and height edits back.
  Garmin data flows in via Apple Health.
- **Accounts + cloud sync** — Sign in with Apple; food / weight / profile follow you
  across devices (last-write-wins, tombstone deletes).
- **Bilingual** — English / 中文, following the iOS system language with a manual
  override in Settings.
- **Theme** — a dark, GXS-style violet palette with a gradient calorie hero.
- **Feedback** — an in-app form that submits to a Google Form.

## How the targets work
- **Calorie budget:** a full day's resting energy (Mifflin-St Jeor BMR) + the
  active energy you've burned (measured via Apple Health, or 0 when it isn't
  connected) + your calorie **gap** (the goal default — lose −500, maintain 0, gain
  +400 — or a custom value). When Health isn't connected the resting + active part is
  replaced by BMR × activity multiplier. Calories left = budget − eaten; the budget
  stays stable through the day so you can plan meals against it. Settings shows this as
  the **Calorie gap target** and lets you edit the calorie gap, protein target, and
  saturated-fat cap directly.
- **Burn** (shown beneath the budget) is your *actual* expenditure so far today —
  measured resting + active energy from Apple Health — so it climbs as the day goes
  on, independent of the budget.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

## Photo analysis (Claude)
Photos are analyzed via Anthropic's Messages API, forcing a `log_food` tool for
structured output (name / calories / protein / saturated fat / portion / confidence).
The Claude key lives **server-side** in an AWS Lambda proxy (see
[`backend/`](backend/README.md)) — the app ships no key and calls the proxy
(`ProxyAnalyzer`), sending only the photo + a build-time app token
(`--dart-define=PROXY_BASE_URL` / `PROXY_APP_TOKEN`). A direct path
(`ClaudeVisionClient` via `DirectAnalyzer`) remains in the code for a user-supplied key
in the iOS Keychain, but isn't surfaced in the UI.

The proxy is defined with AWS SAM (Python); deploy + secret setup are in
[`backend/README.md`](backend/README.md).

## Localization
Uses Flutter `gen-l10n`. Strings live in `lib/l10n/app_en.arb` and `app_zh.arb`; run
`flutter gen-l10n` (or any build) to regenerate `AppLocalizations`. The app follows
the system locale by default and persists a manual choice.

## Status & remaining work

**Done (in `main`):**
- [x] Manual food logging + goal-**gap** targets engine
- [x] Claude photo analysis (server-side key via the AWS proxy)
- [x] Apple Health / Garmin — active + resting energy, weight, height, date of birth
  (→ age) and workouts in; logged food, weight, and height edits written back
- [x] Targets polish — calorie **gap** (±) with edit-all (calorie / protein / sat-fat);
  age / height / weight auto-filled from Apple Health and editable; manual weight log dropped
- [x] First-run onboarding (Sign in with Apple or manual name → goal → connect Health)
  plus a "Finish setting up" checklist on Today
- [x] Today greeting (time-of-day + name) and a location-based animated **weather**
  header — GPS via geolocator, falling back to an approximate IP lookup when
  location is denied; conditions from Open-Meteo (no key)
- [x] Trends — interactive charts (tap / drag to inspect), 1 / 7 / 30-day windows with
  prev/next paging, "on target X/Y" highlight
- [x] Dark GXS-violet redesign — gradient calorie hero, modern type, floating cards
- [x] English / 中文 localization (follows the system language, with a manual toggle)
- [x] In-app feedback → Google Form
- [x] Deploy to iPhone (paid Apple Developer membership active)
- [x] AWS Lambda vision proxy holds the Claude key server-side (SAM + Python, in
  `backend/`); the app ships no key
- [x] Accounts + sync — Sign in with Apple (`/auth/apple`) + DynamoDB delta sync
  (`/sync`), deployed to `ap-southeast-1`; app-side bidirectional sync of food /
  weight / profile (last-write-wins, tombstones; on sign-in / resume / edit / manual)

**TODO:**
- [ ] **Google Sign-In** — fast-follow: `/auth/google` mirroring `/auth/apple`
- [ ] **Subscriptions** — SGD 1.99/month (auto-renew) + SGD 3.99 / 100-day
  (non-renewing) via StoreKit IAP, with server-side receipt validation
- [ ] Later: home-screen widget, reminders, barcode scan, Android

## Tech stack
- **Flutter / Dart**, iOS first (iPhone), then Android and web.
- **Riverpod** for state; **shared_preferences** for local data (behind repositories)
  and **flutter_secure_storage** for tokens/keys; **http**, **image_picker**, the
  **health** package, **geolocator** (weather), **sign_in_with_apple** + **crypto**
  (accounts), **intl** + **flutter_localizations**.

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
                            WorkoutSummary, WeightEntry, MealType, FoodAnalysis,
                            Weather, Session, SyncRecord
    nutrition/              NutritionMath (BMR, TDEE, targets)
    data/                   Food/Profile/Weight repositories, ApiKeyStore,
                            ClaudeVisionClient + FoodPhotoAnalyzer (proxy/direct),
                            HealthService (+io/stub), WeatherService, FeedbackService,
                            AuthClient + SessionStore, SyncClient + sync engine
    providers/              Riverpod providers
    features/               onboarding / today / add / trends / settings / feedback
    theme/ util/            theme, formatting, localized enum labels
test/                       unit + widget tests
ios/                        Runner + Runner.entitlements (HealthKit)
backend/                    AWS SAM vision proxy (Lambda, Python) — holds the Claude key
```
