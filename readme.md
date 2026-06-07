# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat — by hand
or by **snapping a photo** — see how much you can still eat today, and keep an eye
on your protein and saturated-fat quotas. Connects to **Apple Health / Garmin**
for real calories burned, and speaks **English and 中文**. Built with Flutter.

> **Status:** Phases 1–3 + health expansion + "Phase A" polish are complete in
> code (manual logging, targets engine, Claude photo analysis, Apple Health/Garmin,
> purple theme, EN/中文, weight log, feedback). On-device deploy of the health
> features requires a paid Apple Developer account (see [iOS notes](#ios-notes)).
> Next up: AWS backend, Apple/Google login, and subscriptions.

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
- **Calories:** resting metabolic rate via Mifflin-St Jeor. When Apple Health is
  connected, daily burn = measured resting energy (or BMR if a device didn't report
  it) + measured active energy; otherwise BMR × activity multiplier. Daily target =
  burn + goal adjustment (lose -500, maintain 0, gain +400). Calories left =
  target - eaten.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

## Photo analysis (Claude)
`ClaudeVisionClient` calls the Anthropic Messages API, forcing a `log_food` tool for
structured output (name / calories / protein / saturated fat / portion / confidence).
The API key is read in this order:
1. a key entered in **Settings** (stored in the iOS Keychain), else
2. a build-time key baked in via `--dart-define` from a git-ignored `dart_defines.json`.

> Planned: move the key server-side behind an AWS proxy so it never ships in the app.

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
- [x] GXS-style purple theme
- [x] English / 中文 localization (follows the system language, with a manual toggle)
- [x] Manual weight log
- [x] In-app feedback → Google Form

**TODO:**
- [ ] **Deploy to iPhone** — blocked until the paid Apple Developer membership
  activates (HealthKit can't be signed on a free Personal Team)
- [ ] Bake the production Anthropic key into the build (`dart_defines.json`)
- [ ] **AWS backend** — a Lambda vision proxy that holds the Claude key + DynamoDB
  for daily tracking data
- [ ] **Login** — Sign in with Apple + Google Sign-In, with per-user sync
- [ ] **Subscriptions** — SGD 1.99/month (auto-renew) + SGD 3.99 / 100-day
  (non-renewing) via StoreKit IAP, with server-side receipt validation
- [ ] Confirm the exact GXS purple shade
- [ ] Later: trends / charts, home-screen widget, reminders, barcode scan, Android

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

# iOS device (bakes in the Claude key for photo analysis):
cp dart_defines.example.json dart_defines.json   # then add your ANTHROPIC_API_KEY
flutter run -d ios --dart-define-from-file=dart_defines.json
```
`dart_defines.json` is git-ignored, so your key never gets committed.

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
                            ClaudeVisionClient, HealthService (+io/stub), FeedbackService
    providers/              Riverpod providers
    features/               today / add / history / settings / feedback screens
    theme/ util/            theme, formatting, localized enum labels
test/                       unit + widget tests
ios/                        Runner + Runner.entitlements (HealthKit)
```
