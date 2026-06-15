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

## Step 4 — Upload the build — pick ONE

> ✅ **Now automatable headlessly** with an App Store Connect API key (`.p8`) — no
> Xcode GUI needed. This is how the v2 TestFlight builds ship; build `1.0.1 (2)`
> was uploaded this way on 2026-06-15. See **Path D**.

**Path D — App Store Connect API key (headless, recommended):** with the `.p8`
key + its Key ID + Issuer ID (the Issuer ID is at App Store Connect → Users and
Access → Integrations). Bump the build number in `pubspec.yaml` first, then:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Archives fine; its own IPA export fails (no distribution cert) — export separately below:
flutter build ipa --release --dart-define-from-file=dart_defines.json \
  --export-options-plist=ios/ExportOptions.plist
mkdir -p ~/.appstoreconnect/private_keys && cp AuthKey_<KEYID>.p8 ~/.appstoreconnect/private_keys/
# Export-sign — -allowProvisioningUpdates + the key provisions the distribution cert/profile:
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa \
  -allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8 \
  -authenticationKeyID <KEYID> -authenticationKeyIssuerID <ISSUER_ID>
# Upload to App Store Connect / TestFlight:
xcrun altool --upload-app --type ios --file build/ios/ipa/food_at_peace.ipa \
  --apiKey <KEYID> --apiIssuer <ISSUER_ID>
```

> ⚠️ **Adding a new capability (e.g. Associated Domains)?** `flutter build ipa`'s
> *archive* step does **not** pass `-allowProvisioningUpdates`, so it fails with
> *"provisioning profile doesn't include the … entitlement"* until the App ID
> carries that capability. Archive with `xcodebuild` directly + the ASC key so it
> auto-provisions the capability, then export/upload as above. This is how build
> `1.0.1 (4)` (Associated Domains + `foodatpeace://` URL scheme) shipped:
> ```bash
> flutter build ios --config-only --release --dart-define-from-file=dart_defines.json
> cd ios && xcodebuild archive -workspace Runner.xcworkspace -scheme Runner \
>   -configuration Release -archivePath ../build/ios/archive/Runner.xcarchive \
>   -allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8 \
>   -authenticationKeyID <KEYID> -authenticationKeyIssuerID <ISSUER_ID>
> ```

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
  (Health & Fitness / Name / Email / User ID — collected for the optional sync,
  linked, not tracking; Coarse Location + Photos — App Functionality, not linked;
  no tracking).
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

## Resubmission after the 1.4.1 rejection — ✅ DONE (June 12, 2026)

The June 11 rejection (Guideline 1.4.1 — citations for medical information;
reviewed on an iPad Air 11-inch M3 with v1.0 build 1) is addressed in build
**3**: a **Sources & methodology** screen with primary-source citations +
disclaimer, linked from Today ("How your budget is calculated") and Settings.
Build 3 also adds **in-app account deletion** (Settings → Account → Delete
account; Guideline 5.1.1(v)) backed by a deployed `/account/delete` endpoint
that wipes the user's server data and revokes pre-deletion session tokens, and
the `NSLocationAlwaysAndWhenInUseUsageDescription` purpose string (clears
upload warning ITMS-90683 from build 2).

**Resubmitted June 12, 2026 at 4:28 PM — status "Waiting for Review"** (typical
verdict ≤48 h, Apple emails the result; the version auto-releases on approval).
What was done:

1. Build `1.0.0 (3)` uploaded and attached to the iOS 1.0 version.
2. Replied in App Store Connect to the rejection message with the fix summary.
3. Refreshed **App Review notes** (open with the 1.4.1 resolution), contact
   info (incl. phone), keywords, and URLs — all per `STORE_LISTING.md`.
4. Updated **Description** and **Promotional Text** to the current
   `STORE_LISTING.md` copy.
5. Corrected **App Privacy**: Name, Health, and User ID switched to *linked to
   identity* (Email was already linked); Location/Photos stay not-linked; no
   tracking. Republished.
6. Replaced the screenshots with a fresh **6.9″ set** (5 × 1320 × 2868, iPhone
   16 Pro Max simulator) in order Today · Trends · Add · Sources & methodology ·
   Settings — files in `store/app-store-screens/`. Note: 1320 × 2868 is only
   accepted by the **6.9″ slot in Media Manager**; the version page's inline
   box is the 6.5″ slot and rejects it.
7. Verified `store/privacy-policy.html` + `support.html` live on GitHub Pages
   (both 200, policy includes account deletion + sources).

---

## Quick reference

| Thing | Value |
|---|---|
| Bundle ID | `com.foodatpeace.foodAtPeace` |
| Team ID | `GJB4AB92L4` |
| Version / build | `1.0.0 (3)` live on the App Store · `1.0.1 (5)` (v2) on TestFlight |
| IPA output | `build/ios/ipa/food_at_peace.ipa` |
| Build env | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer LANG=en_US.UTF-8` |
