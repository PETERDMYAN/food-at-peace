# Publishing Food at Peace to the App Store

A step-by-step runbook for the first release. Steps marked **(you)** require your
Apple ID / credentials or the App Store Connect website and can't be automated.

The machine is already set up: **Xcode 26.5** and **CocoaPods 1.16.2** work, the
app compiles, and all store-compliance config (privacy manifest, encryption flag,
icons, entitlements, signing team `GJB4AB92L4`) is in place.

---

## Step 0 — Point the toolchain at Xcode  **(you — required, one time)**

The Mac's active developer dir is the Command Line Tools, which has no iOS SDK.
Flutter's native-assets build hook (`objective_c`) ignores `DEVELOPER_DIR`, so the
global switch is required — run once (needs your Mac password):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify: `xcrun --sdk iphoneos --show-sdk-path` should print an `iPhoneOS….sdk` path.

## Step 1 — Sign into your Apple Developer account in Xcode  **(you)**

This is what creates your signing certificates (the Mac currently has none).

1. Open the workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Xcode → **Settings… → Accounts → "+" → Apple ID** → sign in with the Apple ID
   that owns your developer membership.
3. Select the **Runner** target → **Signing & Capabilities** tab:
   - ✅ **Automatically manage signing**
   - **Team** = your team (should already read `GJB4AB92L4`)
   - Confirm **HealthKit** is listed under Capabilities (it is in the entitlements).
   - Xcode should show "Signing Certificate: Apple Development…" with no red errors.

## Step 2 — Register the App ID & create the app record  **(you)**

1. **App ID** (if not auto-created): [developer.apple.com](https://developer.apple.com/account)
   → Certificates, IDs & Profiles → **Identifiers → "+" → App IDs → App**
   - Bundle ID (explicit): `com.foodatpeace.foodAtPeace`
   - Enable capability: **HealthKit**
2. **App record**: [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   → My Apps → **"+" → New App**
   - Platform: **iOS**
   - Name: **Food at Peace**
   - Primary language: **English (U.S.)**
   - Bundle ID: **com.foodatpeace.foodAtPeace**
   - SKU: any unique string, e.g. `foodatpeace-001`
   - Full access

## Step 3 — Build the signed release IPA

Photo analysis runs through the AWS proxy (see [`backend/`](backend/README.md)), so
**no Anthropic key is baked into the build** — only the proxy URL + app token, injected
at build time via `--dart-define` and **not** in the repo. Deploy the proxy first
(`backend/README.md`), fill in `dart_defines.json`, then:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer LANG=en_US.UTF-8
flutter build ipa --release \
  --dart-define-from-file=dart_defines.json \
  --export-options-plist=ios/ExportOptions.plist
```

- `dart_defines.json` holds `PROXY_BASE_URL` + `PROXY_APP_TOKEN` (git-ignored).
- Output: `build/ios/ipa/food_at_peace.ipa`
- The app ships no Claude key. The app token is revocable (rotate it in SSM) and the
  proxy rate-limits + caps concurrency, so a leaked token has a bounded blast radius.
- If signing fails on this first run, do the archive once via Xcode GUI instead
  (**Step 3-alt**) — it creates the distribution certificate interactively.

### Step 3-alt — Archive via Xcode GUI (fallback if CLI signing fails)  **(you)**

> ⚠️ First run the CLI build once (it stores the `--dart-define` values in
> `ios/Flutter/Generated.xcconfig`), then archive in Xcode:

1. `open ios/Runner.xcworkspace`
2. Top device selector → **Any iOS Device (arm64)**
3. **Product → Archive**
4. When done, the Organizer opens → continue to Step 4 path B.

## Step 4 — Upload the build  **(you)** — pick ONE

**Path A — Transporter (easiest):** install **Transporter** from the Mac App
Store, sign in, drag `build/ios/ipa/food_at_peace.ipa` in, click **Deliver**.

**Path B — Xcode Organizer:** in the Organizer (from Step 3-alt) select the
archive → **Distribute App → App Store Connect → Upload** → Next through the
defaults (automatic signing, upload symbols).

**Path C — command line:** create an app-specific password at
[appleid.apple.com](https://appleid.apple.com) (Sign-In & Security → App-Specific
Passwords), then:
```bash
xcrun altool --upload-app -f build/ios/ipa/food_at_peace.ipa -t ios \
  -u YOUR_APPLE_ID_EMAIL -p xxxx-xxxx-xxxx-xxxx
```

After upload, the build takes ~5–30 min to finish "Processing" in App Store
Connect before you can select it.

## Step 5 — Fill in the listing  **(you)**

In App Store Connect → your app → the **1.0.0** version. Use `store/STORE_LISTING.md`
for ready-to-paste copy.

- **Screenshots** (required): 6.7" iPhone, 1290×2796. See `store/SCREENSHOTS.md`
  for how to capture them.
- **Description / Keywords / Promotional text / What's New**: from `STORE_LISTING.md`.
- **Support URL** and **Privacy Policy URL**: host `store/privacy-policy.html`
  (see below) and paste the URLs.
- **General → App Privacy**: answer the questionnaire per `STORE_LISTING.md`
  (Photos → App Functionality; everything else not collected; no tracking).
- **Age rating**: answer all "None" → 4+.
- **Build**: select the build you uploaded in Step 4.
- **App Review Information → Notes**: paste the review notes from `STORE_LISTING.md`
  and add your contact name/phone/email.

### Hosting the privacy policy (free, via GitHub Pages)

Your repo is on GitHub (`PETERDMYAN/food-at-peace`). Easiest:
1. Repo → **Settings → Pages** → Source: **Deploy from a branch** → `main` / `/root`.
2. After it builds, the pages are at:
   - Privacy Policy: `https://PETERDMYAN.github.io/food-at-peace/store/privacy-policy.html`
   - Support: `https://PETERDMYAN.github.io/food-at-peace/store/support.html`
   (Both already have your email `peter.yandongming@gmail.com` filled in.)
3. These files are committed to the repo, so they publish automatically once Pages is on.

## Step 6 — Submit for review  **(you)**

Click **Add for Review → Submit**. First reviews typically take 1–3 days. If the
reviewer flags photo analysis (meal photos are sent to Anthropic via our proxy) or
HealthKit, the review notes already explain both; reply in Resolution Center if they
need more.

---

## Quick reference

| Thing | Value |
|---|---|
| Bundle ID | `com.foodatpeace.foodAtPeace` |
| Team ID | `GJB4AB92L4` |
| Version / build | `1.0.0` / `1` |
| IPA output | `build/ios/ipa/food_at_peace.ipa` |
| Build env | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer LANG=en_US.UTF-8` |
