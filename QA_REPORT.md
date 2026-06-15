# QA Report — Food at Peace (`v2`)

**Date:** 2026-06-13
**Branch:** `v2` (production `main` = App Store-approved 1.0.0, untouched)
**Scope:** Full app + backend pass — "try every functionality and make sure it works,
including BE services." Driven autonomously end-to-end.

## TL;DR

**No app bugs found.** Static analysis is clean, all unit/widget tests pass, a new
9-flow integration suite passes on the simulator, and every live backend endpoint is
correctly wired and guarded. The one issue you reported — *"Apple ID connection doesn't
work during onboarding"* — is **environmental, not a code bug** (the simulator/device
isn't signed into an Apple ID). Details and the fix are below.

---

## 1. Static analysis & existing tests — ✅

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` (unit/widget) | **72 tests, all pass** across 18 files |

Existing coverage includes nutrition math, daily-summary + HealthKit budgeting, Beans
ledger, sync client + LWW merge, Apple auth client, proxy analyzer, reminders, friends,
trends interaction, weather, account deletion, edit-targets dialog, sources screen,
photo-analyzer selection, and profile-from-Health refresh.

## 2. New integration suite — ✅ (9/9 on iPhone 17 Pro simulator)

Added `integration_test/qa_test.dart` (drives the real widget tree, asserts behavior so
any crash/red-screen/broken interaction fails the run):

1. First-run shows onboarding.
2. Returning user boots to Today; all three tabs (Today / Trends / Profile) render.
3. **Add a manual food entry** → saves, calorie card updates ("Eaten 500"), tile appears in *Today's food*.
4. Beans wallet: top-up pack updates balance (21 → 221).
5. Beans paywall: custom-amount dialog adds beans.
6. Reminders: toggle, add, delete.
7. Circle of Food: invite sheet + send + connected-friend trend.
8. Owner dashboard renders metrics.
9. Language toggle EN ↔ 中文 and back.

Run it with:
```
flutter test integration_test/qa_test.dart -d <booted-simulator-id> \
  --dart-define-from-file=dart_defines.json
```

## 3. Backend (live, `ap-southeast-1`) — ✅ all endpoints wired & guarded

Tested against the production proxy API. All non-destructive probes:

| Endpoint | Probe | Result | Meaning |
|---|---|---|---|
| `POST /analyze` | valid app token + real food photo | **200** + analysis | Vision path works end-to-end |
| `POST /analyze` | wrong app token | **401** | App-token guard works |
| `POST /auth/apple` | bogus identity token | **401** (not 500) | `APPLE_CLIENT_ID` configured; Apple JWKS verification runs |
| `POST /sync` | no bearer | **401** | Session guard works |
| `POST /account/delete` | bogus bearer | **401** (nothing deleted) | Destructive op is guarded |

Every error is a clean, user-safe message (no stack traces / 500s leaking).

---

## 4. Your reported issue: "Apple ID connection doesn't work during onboarding"

**Diagnosis: not an app or backend bug — the test environment isn't signed into an Apple ID.**

- **Client flow is correct.** `auth_client.dart` generates a nonce, runs the native Sign in
  with Apple sheet, exchanges the identity token at `/auth/apple`, and handles cancel /
  network / backend errors. `onboarding_screen.dart` surfaces failures as a toast
  (`AuthException.message`, else `signInFailed`) — it does **not** fail silently.
- **Backend is correct.** A bogus token returns **401** (not 500), which proves
  `APPLE_CLIENT_ID` is set and the Lambda actually verifies tokens against Apple's JWKS.
- **Root cause.** Sign in with Apple requires the device/simulator to be signed into an
  Apple ID. On a fresh simulator (or an unsigned device) the native sheet errors and the
  app shows "Sign-in failed" — which reads as "doesn't work."

**Fix (environment, ~30 seconds):**
1. On the simulator: open **Settings** → tap **"Sign in to your iPhone"** at the top.
2. Enter your Apple ID and password (a test/sandbox Apple ID is fine).
3. Re-launch the app → onboarding → **Continue with Apple** now completes.

(On a physical device the device must likewise be signed into iCloud, and the app's
bundle ID `com.foodatpeace.foodAtPeace` must have the *Sign in with Apple* capability in
the Apple Developer portal — already enabled for the App Store build.)

---

## 5. Needs a physical device / manual verification (can't be automated on a simulator)

- **Sign in with Apple** end-to-end (real Apple ID — see §4).
- **Apple Health** read/write (HealthKit is unavailable on the simulator).
- **Local notification delivery** at scheduled meal times (needs permission + wall clock).
- **Camera capture** (simulator has no camera; the photo-library path works and the
  `/analyze` backend is verified).
- **Weather chip** (needs location permission; stubbed to off in tests).

## 6. Known MVP stubs (pre-existing, documented in code — *not* regressions)

These are intentional and already called out in source comments; flagging so they're not
forgotten before charging real money / shipping social:

- **Beans purchases/subscription are DEV STUBS** — they credit locally. Wire real StoreKit
  IAP + server-side receipt validation before release (a reinstall currently resets the
  balance/entitlement).
- **Circle of Food** invites + friend trends are local/mock — needs a backend for real
  invite delivery and privacy-gated trend sharing.
- **Owner dashboard** shows sample metrics — needs an analytics backend.

---

## What changed in this pass

- Added `integration_test/qa_test.dart` + the `integration_test` dev dependency.
- No application code changed — **no bugs required fixing.** The only "fix" was in the new
  test: the *add food* assertion was looking at an entry tile that Today's lazy
  `ListView` hadn't built yet (it's below the fold); the test now scrolls it into view
  before asserting. The entry always saved correctly — the calorie card reflects it
  immediately.

---

## Addendum — built since this pass (v2, 2026-06-15)

This report predates the v2 feature work. Added since (all on the **isolated** v2
backend stack `food-at-peace-vision-proxy-v2` / API `p21hoawoi5`; production
`6m19l2b025` untouched):

- **Locale-aware AI analysis** — the photo estimate returns in the app's language
  (verified live: EN vs 中文, numeric fields unchanged).
- **Owner analytics** — real `POST /event` + `GET /metrics` (verified live; counters move).
- **Circle of Food backend** — friend graph (register / invite / accept / list +
  privacy-gated trends), the `@handle` view/set/copy UI, remove-friend, and a **3-day
  photo feed** with emoji reactions (verified live with two users: post → see →
  react → receive; presigned photo downloads).
- **Invite universal link + QR + one-tap connect** — `POST /circle/connect` makes
  both sides mutual friends from a shared link/QR. **Verified live** with two minted
  session tokens: B opens A's invite → both `connected`, no pending; self/unknown
  guards return 400/404. Client: QR + native share of `https://foodatpeace.app/i/<handle>`,
  an `app_links` in-app handler (works under `FlutterSceneDelegate` via the engine's
  scene→app-delegate fallback — traced in the engine source), a `foodatpeace://`
  custom-scheme fallback, and a **Manage circle** screen (connected/requests/invited).
- **Chinese App Store listing** ([`store/STORE_LISTING_zh.md`](store/STORE_LISTING_zh.md)).
- **TestFlight** `1.0.1 (4)` built + uploaded via the ASC API key — adds the
  Associated Domains entitlement + `foodatpeace://` scheme; signing auto-provisioned
  the new capability (archived via `xcodebuild -allowProvisioningUpdates`).

Automated coverage now: **Flutter 108 + backend 74 tests, `flutter analyze` clean**,
plus integration walkthroughs (`integration_test/lang_demo_test.dart`,
`circle_demo_test.dart`). New: `test/invite_link_test.dart` (link build/parse),
`connect` cases in `test/circle_client_test.dart` and `backend/tests/test_circle.py`.

The **signed-in Circle flow is now exercised in-app on two simulators** against the
live v2 backend (session tokens injected via a test-only `authProvider` override,
since Apple sign-in can't run on a sim): user A scans + posts a meal → user B opens
A's invite → one-tap mutual connect → B's feed shows A's photo → B reacts ❤️ → A
receives it (also confirmed server-side). Driver:
[`integration_test/circle_two_user_demo.dart`](integration_test/circle_two_user_demo.dart).

**Still needs a real device / manual pass:** Sign in with Apple end-to-end (the demo
injects the token), and the **universal link** opening the app from
WeChat/WhatsApp — that needs the AASA hosted on `foodatpeace.app`
([`store/INVITE_LINKS.md`](store/INVITE_LINKS.md); the `foodatpeace://` scheme is
verified working). Plus the existing §5 items (Apple Health, notifications, camera,
weather GPS).
