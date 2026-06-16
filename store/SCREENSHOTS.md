# Capturing App Store screenshots

> **Current shipped set (1.0.1, 2026-06-16):** a **bilingual** 6 × 1320 × 2868 set —
> `store/app-store-screens/` (English) and `store/app-store-screens-zh/` (简体中文) —
> uploaded to the **6.9″ Display** slot in Media Manager, order: **Today · Circle ·
> Scan · Trends · Beans · Settings**. (1320 × 2868 is only accepted by the 6.9″ slot;
> the version page's inline box is the 6.5″ slot.)
>
> **These are generated, not hand-captured.** `integration_test/store_screenshots.dart`
> seeds a configured account (profile, a week of meals, a Beans ledger, a Circle feed
> with hosted photos), forces a locale, and walks the screens; a tiny host server
> (`/tmp/fap_shots/shotserver.py`) captures the *device* screen via `simctl` (so the
> clean 9:41 status bar is included) when the test pings `127.0.0.1` per screen.
> Regenerate both sets on a booted **iPhone 17 Pro Max** (also 1320 × 2868):
>
> ```bash
> # host capture server (writes /tmp/fap_shots/out/<name>.png on GET /shot/<name>)
> SHOT_UDID=<udid> nohup python3 /tmp/fap_shots/shotserver.py 8099 &
> xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged \
>   --batteryLevel 100 --cellularBars 4 --wifiBars 3 --operatorName ""
> flutter test integration_test/store_screenshots.dart -d <udid> --dart-define=LOCALE=en
> flutter test integration_test/store_screenshots.dart -d <udid> --dart-define=LOCALE=zh
> ```
>
> _Historical:_ the prior 1.0.0 set was 5 hand-captured shots (Today · Trends · Add ·
> Sources · Settings) on the iPhone 16 Pro Max.

App Store Connect requires **6.7-inch iPhone** screenshots at **1290 × 2796 px**
(this one set covers all current iPhone sizes). 1–10 images; the first 3 show in
search, so lead with your strongest.

The right simulator for that exact resolution is **iPhone 15 Pro Max** (or 16 Pro
Max, also accepted at 1320×2868).

## 1. Boot the simulator and run the app

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer LANG=en_US.UTF-8

# Boot the 6.7" device
xcrun simctl boot "iPhone 15 Pro Max" 2>/dev/null
open -a Simulator

# Run the app on it (proxy config makes the photo-analysis screen work)
flutter run -d "iPhone 15 Pro Max" \
  --dart-define-from-file=dart_defines.json
```

## 2. Populate it for good shots

Add a few realistic food entries and set your profile in Settings so the rings
and quota cards look full. Suggested 5 screens:

1. **Today** dashboard — greeting + weather chip, calories-left ring,
   protein/sat-fat cards (with data).
2. **Add** — manual entry form.
3. **Photo analysis** — the estimate/confirm screen after analyzing a meal photo.
4. **Trends** — the daily charts with the on-target badges (log a few days first).
5. **Settings** — profile + targets, with the Sources & methodology card visible.

## 3. Capture (exact 1290×2796 PNGs)

With the screen ready in the simulator:

```bash
xcrun simctl io booted screenshot ~/Desktop/fap-01-today.png
xcrun simctl io booted screenshot ~/Desktop/fap-02-add.png
xcrun simctl io booted screenshot ~/Desktop/fap-03-photo.png
xcrun simctl io booted screenshot ~/Desktop/fap-04-history.png
xcrun simctl io booted screenshot ~/Desktop/fap-05-settings.png
```

(`Cmd+S` in the Simulator also saves a correctly-sized screenshot to the Desktop.)

## 4. Verify size, then upload

```bash
sips -g pixelWidth -g pixelHeight ~/Desktop/fap-01-today.png   # expect 1290 x 2796
```

Drag the PNGs into the **6.7" Display** slot of your version in App Store Connect.

> Tip: localized listings — you can add a separate Chinese (Simplified) screenshot
> set later, but it's optional for first submission.
