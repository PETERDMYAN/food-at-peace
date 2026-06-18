# Ship a user-facing feature (Food at Peace)

Use this whenever the user asks for a **user-facing feature change** (anything they
see or touch in the app). After implementing, run the full ship sequence below —
**don't stop at "code done."** The user expects to *see it* and have it *on their
phone*.

## 0. Implement
- Build on the existing patterns (providers → data → models; `circle_strip.dart`,
  `story_viewer.dart`, `MealPhotos`/`ProfilePhoto` for local images, l10n in the
  `.arb` files — never hand-edit `app_localizations*.dart`).
- Keep `flutter analyze` clean and `flutter test` green before moving on. For
  backend touches also `pytest backend/tests/` + `sam validate`, and obey the
  `production-safety` skill (additive, v2 first, confirm prod).

## 1. Before / after screenshots — always show the user
Capture on the booted sim via the screenshot harness (it drives real screens):
1. Start the host capture server + clean status bar:
   - `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi --cellularMode active`
   - `python3 /tmp/fap_shots/shotserver.py` (port 8099) in the background.
2. Capture **BEFORE** *first* (git stash or screenshot the current build), then
   the **AFTER** once the change is in. Reuse prior shots in `/tmp/fap_shots/out/`
   as "before" when they exist.
3. Add/keep capture steps in
   [`integration_test/store_screenshots.dart`](integration_test/store_screenshots.dart)
   (tap the surface, `shot(t, 'NN-name')`). Full-screen routes dismiss via the ✕
   (`find.byIcon(Icons.close)`), not a scrim tap.
4. Run: `flutter test integration_test/store_screenshots.dart -d <udid> --dart-define=LOCALE=en`
5. **`SendUserFile` the before + after** with a one-line caption of what changed.

## 2. Deploy to TestFlight
- Bump `pubspec.yaml` build number (`1.0.2+N`).
- `sed` a new `/tmp/fap_rec/buildNN.sh` from the last one (it points at PROD via
  `dart_defines.prod.json`, archives with `-allowProvisioningUpdates`, exports,
  and `altool --upload-app` with the ASC key `3FQVCHD8RS`). Run it; confirm
  **ARCHIVE / EXPORT / UPLOAD SUCCEEDED** + a Delivery UUID.

## 3. Deploy to PY (the user's phone) — if available
- Check for a connected physical device: `xcrun devicectl list devices` (or
  `flutter devices`). If a real iPhone is present and trusted:
  `flutter run -d <device-id> --release --dart-define-from-file=dart_defines.prod.json`
  (or install the built `.app`/`.ipa` with `xcrun devicectl device install app`).
- If **no device is connected**, say so and note TestFlight covers it — don't block.

## 4. Commit + push to the relevant branch
- Update `TODO.md` + `readme.md` (the `docs-before-commit` skill), stage with the
  code, commit, and `git push origin <current branch>` (today: `v3`).

## Done = the user has seen before/after, the build is on TestFlight (and their
phone if connected), and it's committed + pushed. Report each with evidence.
