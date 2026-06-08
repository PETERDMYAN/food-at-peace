# Capturing App Store screenshots

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

1. **Today** dashboard — calories-left ring + protein/sat-fat cards (with data).
2. **Add** — manual entry form.
3. **Photo analysis** — the estimate/confirm screen after analyzing a meal photo.
4. **History** — entries grouped by day.
5. **Settings** — profile with the live targets preview.

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
