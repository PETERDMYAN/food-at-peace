# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat, see how
much you can still eat today, and keep an eye on your protein and saturated-fat
quotas. Built with Flutter.

> **Status: Phase 1 complete** — manual logging plus the full targets engine.
> Photo analysis (Claude vision) and Apple Health / Garmin "calories out" are on
> the roadmap below.

## What it does today
- **Today dashboard** — calories left for the day (a progress ring) plus protein
  and saturated-fat quota cards (consumed / target, with how much is left or over).
- **Add food** — manual entry of calories, protein, saturated fat, meal, serving.
- **History** — entries grouped by day with daily calorie totals.
- **Settings** — your profile (sex, age, height, weight, activity, goal) with a
  live preview of your BMR, daily burn, and calorie / protein / saturated-fat targets.

## How the targets work
- **Calories:** Mifflin-St Jeor BMR x activity multiplier = estimated daily burn.
  Daily target = burn + goal adjustment (lose -500, maintain 0, gain +400).
  Calories left = target - eaten.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

## Roadmap
- **Phase 2 — Calories out from HealthKit:** read basal + active energy via the
  `health` package. Garmin data flows in automatically through Apple Health.
- **Phase 3 — Photo analysis:** snap a meal, Claude estimates calories / protein /
  saturated fat, you confirm before logging.
- **Phase 4 — Richer targets & goals.**
- **Later:** trends / charts, home-screen widget, reminders, barcode scan, Android.

## Tech stack
- **Flutter / Dart**, targeting iOS first (iPhone), then Android and web.
- **Riverpod** for state, **shared_preferences** for local storage (behind a
  repository so it can move to Drift / SQLite later), **intl** for formatting.

## Getting started
```bash
flutter pub get

# Run in a browser (UI + manual logging; no HealthKit / camera):
flutter run -d chrome

# Run on iOS (requires Xcode installed):
flutter run -d ios
```

### Tests & checks
```bash
flutter analyze
flutter test
```

## Project layout
```
lib/
  main.dart                 app entry (loads storage, sets up Riverpod)
  app.dart                  MaterialApp + theme
  src/
    models/                 FoodEntry, UserProfile, DailySummary, MealType
    nutrition/              NutritionMath (BMR, TDEE, targets)
    data/                   FoodRepository, ProfileRepository
    providers/              Riverpod providers
    features/               today / add / history / settings screens
    theme/ util/            theme + formatting helpers
test/                       unit + widget tests
```
