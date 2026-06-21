---
name: verify-in-simulator
description: >
  Apply after ANY change to the Flutter app (anything under lib/ the user can see
  or touch) and BEFORE calling it done or shipping a build. Build/run it on the
  iOS simulator and verify it both LOOKS right and WORKS: layout + usability, key
  data loads (food log, meal photos in Today / story / archive), a brand-new user
  can onboard and reach the Circle and see Eva (and Roro), and follow / unfollow
  works. If any of it is broken, FIX it, then re-verify. Triggers: finished an app
  code change, about to ship a TestFlight build, or touched the Circle / feed /
  story / onboarding / Today / Settings UI.
---

# Verify every app change in the simulator

"Code compiles / tests pass" is **not** done. After any user-facing change, prove
it on a booted simulator — *see* it, *use* it, and confirm the core flows still
work — then fix whatever's broken **before** you ship. The user has been explicit:
they keep finding visual/usability/data bugs that analyze + unit tests never catch.

## 0. Pre-checks (necessary, not sufficient)
`flutter analyze` clean + `flutter test` green; backend touched → `pytest
backend/tests/`. These say nothing about *how it looks or behaves* — they're table
stakes, the verification is below.

## 1. Run it on a booted simulator
- Booted sims: `xcrun simctl list devices booted`. The shot harness defaults to
  iPhone 17 Pro Max (`SHOT_UDID=5E42A674-12B1-4B46-9C48-45E586805B0E`).
- Two ways to drive **real** screens:
  - **Screenshot harness (preferred — deterministic capture):** run
    `python3 /tmp/fap_shots/shotserver.py` (env `SHOT_UDID` / `SHOT_OUT=/tmp/fap_shots/out`)
    in the background, then an integration test that pings `GET /shot/<name>` when a
    screen is settled. Reuse / copy the existing ones:
    `integration_test/circle_strip_shots.dart`, `avatar_shots.dart`,
    `roro_consistency.dart`, `archive_photo_repro2.dart`. Invoke:
    `flutter test integration_test/<file>.dart -d <udid> --dart-define=...`.
    Screenshots land in `/tmp/fap_shots/out/` — **Read them and actually look.**
    (If `shotserver.py` was cleaned from /tmp, recreate it: a tiny HTTP server that
    runs `xcrun simctl io <udid> screenshot <out>/<name>.png` on `GET /shot/<name>`.)
  - **Interactive:** `flutter run -d <udid> --dart-define-from-file=dart_defines.prod.json`
    and drive by hand for exploratory checks.
- Device-only flows can't run on the sim (Sign in with Apple, camera, HealthKit,
  GPS). Stub them in the harness like the existing shot tests do: faked image
  picker, `weatherProvider` → null, and `overrideWith` on `authProvider` /
  `circleProvider` / `circleFeedProvider` / `foodEntriesProvider` to seed state.

## 2. The checklist — every item, every time
Inspect the screenshots / snapshot; never assume:
- [ ] **Looks right** — layout, spacing, no overflow/clipping, dark theme intact,
  the changed surface matches intent.
- [ ] **Usable** — tap targets reachable, nothing crammed behind a divider / nav
  bar / status bar, scrolling works where expected.
- [ ] **Key data loads** — the **food log** (Today list) shows entries; **meal
  photos** render in Today, in the **story** (tap an avatar) AND the **archive**
  (history icon) — both the local-file and synced-thumb paths; no blank/black
  cards where a photo or content should be.
- [ ] **New-user onboarding** — a *fresh* user can finish onboarding and land on
  the **Circle** tab, seeing **Eva** and the official **@roro** (the feed is not
  empty for a brand-new / signed-out user).
- [ ] **Follow / unfollow** — following adds the account and refreshes the feed;
  unfollowing removes it from the strip + feed + Manage; the follow-state is
  **consistent** across strip, feed, and Manage (e.g. never "Suggested: follow
  Roro" while his story + feed are on screen).

## 3. If anything is broken — fix it, then re-verify
Do **not** report a half-working change. Diagnose from the screenshots + source,
fix the source, re-run the harness, and confirm the checklist passes. When the
cause isn't obvious, **reproduce it with a focused integration test** — that's how
the "black archive card", "fake Roro trend", "double Roro", and "feed not
refreshing" bugs were pinned and fixed.

## 4. Only then ship
After the checklist passes: `ship-feature` (before/after pictures) +
`docs-before-commit` + the TestFlight build.
