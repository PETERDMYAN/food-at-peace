# Food at Peace

A calorie & macro tracker for iOS (and later Android). Log what you eat — by hand
or by **snapping a photo** — see how much you can still eat today, and keep an eye
on your protein and saturated-fat quotas. Connects to **Apple Health / Garmin**
for real calories burned, and speaks **English and 中文**. Built with Flutter.

> **Status:** **v1.0.1 (14) is approved & live on the App Store** (the CN name is **食之安**).
> Repo is now a single `main` branch; the live build is tagged **`v1.0.1`** (commit `1c6ca03`).
> **Web recharge (new, this session):** a standalone Stripe top-up page at **`foodatpeace.app/recharge`**
> credits the same server Beans ledger via a signature-verified, idempotent webhook — a no-Apple-cut
> path that also covers Android/web users with no StoreKit. Built + unit-tested on the **v2** stack;
> it's a *standalone* page (no in-app link, so the App Store app is untouched), and awaits Stripe keys
> + a deliberate prod cutover before it's user-facing.
> **1.0.2 (28)** is **in App Review**. **Build 40** aligns the Manage-circle handle avatar with the
> rows below it (was larger + offset). **Build 39** makes the food story show **S3-backed meal photos
> even when no thumbnail synced** (so durable photos reappear after a reinstall, not just a caption);
> older meals logged before durable backup remain unrecoverable. **Build 38** hardens profile restore — the client now never
> pushes an *unconfigured* profile, so a fresh install can't overwrite the real server profile before
> it's pulled back (reinstall-safe, not just update-safe). **Build 37** makes the **notification call-to-action** actually
> get OS permission: the "Turn on notifications" card prompts on first tap, then becomes **"Open
> Settings"** (one tap into the app's iOS Settings) — the in-app toggles stay default-on but are
> independent of the OS permission. **Build 36** fixes **profile restore on reinstall** (the
> profile stayed blank even on prod: launch-time HealthKit refresh stamped the fresh local profile
> newer than the server, so last-write-wins discarded the real one — now a *configured* server
> profile always wins over an *unconfigured* local one) and adds a **tappable avatar on the Manage
> Circle handle card** (opens your story). **Build 35** rebuilds the app against the **production
> backend** (`6m19l2b025`): a returning user who reinstalled saw blank data because this session's
> builds 33/34 were accidentally pointed at the empty **v2/dev** stack — their real data (profile +
> 24 meals + weight) was safe on prod the whole time. Reinstalling build 35 restores everything;
> the main app must always build with `dart_defines.prod.json` (CLAUDE.md guardrail added).
> **Build 34** is a Circle polish pass: story avatars now show
> a **grey "seen" ring** once viewed, **Roro sits left of the ＋** with the official accounts,
> **"Unfollow"** is the one consistent word everywhere (was a mix of "Unfollow" / "Remove from
> circle"), and a strong **"Turn on notifications"** card appears when circle alerts are on but iOS
> permission hasn't been granted (so the default-on toggle actually means something). **Build 33**
> fixes the **IAP purchase feedback**: after
> Apple's payment sheet closed there was only a tiny spinner while the receipt validated, so a paid
> top-up felt like *"nothing happened"* — the Beans paywall now shows a clear full-screen
> **"Processing your payment…"** state and then a **success view** (✓ "Added N Beans" + new balance)
> once the Beans actually land. **Build 31** adds **official Circle accounts** — **Eva**
> (the AI coach) is now a followable member with her daily lesson,
> default-followed and unfollowable (she moves to **Suggested** to re-follow); **Roro** (the
> creator's real account) is **recommended** to follow, opt-in only (never auto-followed, so no
> data-sharing without consent). Both carry an **Official** badge — first-party, not fabricated
> peers. Build 31 also makes the **profile photo durable** (S3, survives reinstall). **Build 29**
> carries the **meal-photo durability
> fix**: the synced photo copy now adaptively shrinks so its base64 always stays under
> DynamoDB's 400 KB row limit — a detailed 1080px photo could previously exceed it and silently
> fail to sync (then vanish after a reinstall); the prod sync endpoint was also hardened so one
> oversized row can't fail the whole push. **Build 30** adds the **proper fix — a durable per-user
> S3 photo store**: the full-resolution original is uploaded to S3 (presigned URLs, no size limit)
> and restored to the Food story on any device, with the synced thumbnail as the instant/offline
> preview. **Android:** the Flutter app now **builds + runs on Android** (emulator-verified) —
> JDK17/SDK toolchain, minSdk 26 + core-library desugaring, AndroidManifest with internet/camera/
> location/notifications + **Health Connect** perms + **foodatpeace.app deep links**,
> `MainActivity` on `FlutterFragmentActivity` (so all plugins register), and a platform-aware
> health service. **Remaining for a Play release (need Google accounts):** Sign in with Apple on
> Android (Apple Services ID), FCM push, Google Play Billing, and the Play Console listing.
> **Submitting next: `1.0.2 (28)`** (prod backend) — the full v3 feature wave (Circle stories:
> photo-hero food story, Calm Eva scenes, story tray + swipe, 7-day archive + delete; profile
> photo; synced meal photos; "Take daily" recurring foods; Data Sources energy priority;
> Circle activity on by default) **plus a fix so a new user no longer sees seeded sample
> friends**. Build (28)
> adds a **⋯ menu on every Circle post — Report (Apple Guideline 1.2 reason picker; the post
> hides for you immediately) and Unfollow (removes the friend both ways)** — closing the last
> UGC-safety gap before submission. Build (26)
> turned **Circle activity notifications on by default** (permission requested when a friend
> first does something; an explicit off sticks). Build (25)
> adds **Data sources** in Settings — choose which device's active energy takes priority when
> several (Garmin, Apple Watch, iPhone) write to Apple Health. Build (24)
> has **"Take daily" foods** — tap an item in 今日饮食 to mark a supplement/staple as daily,
> counted every day with a Daily badge, no re-logging (the post-save prompt from build 23 was
> removed per feedback). It also **fixes Food-story delete** so it no longer removes the
> food-log entry. Build (22)
> makes the stories a **tray** — swiping past the end of your food story rolls into **Eva's**
> story instead of closing — and bumps the **synced photo to 1080px** so it looks crisp on
> every device. Build (21) added **left/right swipe** navigation (tap still works). Build (20)
> **fixes meal photos not showing in the food story** — they were device-local only, so synced
> or older entries fell back to the nutrient card; a small thumbnail now rides on the entry and
> **syncs across devices / survives a reinstall** (no backend change). Build (19) was a **story
> polish** batch: the **Food story** is **photo-hero** (the meal photo fills the
> frame, calories/macros become a caption), **Eva's lesson is a Calm-style scene** (a
> per-lesson gradient + warm glow across all 100 lessons), the food story spans the **last 7
> days** with a **per-story delete**, and you can set a **profile photo** (in Settings) that
> shows in your circle **You** avatar + story header. Build (18) added the full-screen
> **Food story** + per-entry meal photos; (17) the first Circle-stories cut + the **Haiku**
> photo-analysis model (~3–4× cheaper, server-wide), a real **25-Bean** IAP (`beans_25`), a
> **rate-the-app prompt** (5th open), and **`purchase` analytics**; it becomes the 1.0.2
> submission after 1.0.1 clears review.
> Active development is on the **`v3`** branch, which adds: AI photo estimates
> **in your app language** (EN/中文), the **Circle of Food** social layer (friends
> by `@handle`, **invite universal link + QR with one-tap mutual connect**, a
> **Manage circle** screen, privacy-gated friend trends, and a 3-day photo
> **"stories"** feed with emoji reactions), a **real owner-analytics** backend,
> daily meal reminders, and a **Beans** credit wallet. Day-to-day dev still runs
> against the **isolated `food-at-peace-vision-proxy-v2` stack**, while the public
> 1.0.1 release points at the **migrated prod stack** (the v2 backend was deployed
> onto prod additively on 2026-06-16, leaving 1.0.0 users' data intact) — see
> `CLAUDE.md` / [`backend/README.md`](backend/README.md).
> The **invite links are live**: `foodatpeace.app` is registered + hosted on AWS
> (Route53 + CloudFront/HTTPS) serving the AASA + a smart `/i/<handle>` page (app
> installed → opens the app · not installed → App Store · WeChat → tap ••• (top-right)
> → **用默认浏览器打开** hand-off) — see [`store/INVITE_LINKS.md`](store/INVITE_LINKS.md).
> **Beans are real now**: a StoreKit paywall (consumable packs) backed by a **server
> ledger that follows the account**; the buy shows a spinner + can't be double-fired,
> and a purchase is **validated server-side against Apple's receipt** (`/iap/validate`)
> before crediting (the hidden 1-Bean dev pack is debug-only). Circle notifications
> arrive as **real Apple banners** — foreground, and **background via APNs push**
> (build 14) for friend requests, accepts, shared meals, and reactions.
> Earlier: v1.0.0 cleared the Guideline 1.4.1 rejection with the in-app Sources &
> methodology screen + in-app account deletion (see `PUBLISHING.md`).

## What it does today
- **Onboarding** — on first launch: continue with **Sign in with Apple** (pulls your
  name) or type it, pick a goal, connect Apple Health, then "About you"
  (sex / age / height / weight — prefilled from Apple Health, never guessed).
  Anything you skip shows up as a "Finish setting up" checklist on Today.
- **Today dashboard** — a large time-of-day greeting ("Good evening, …" with an emoji)
  and your local **weather** (animated background reflecting rain/sun/cloud/snow +
  a temperature/condition chip; falls back to an approximate IP location if you
  decline GPS). A calorie ring (budget = burn + your calorie *gap*),
  protein and saturated-fat cards, and a card of today's workouts.
- **Add food** — manual entry, or **scan a meal photo** and let Claude estimate the
  calories / protein / saturated fat for you to confirm — **in your app language**
  (EN/中文). You can also share the scan to your **Circle** (below).
- **Circle of Food** — a social layer on **Trends**: claim a `@handle`, **share an
  invite link or QR** (one tap connects you both as mutual friends) or invite by
  handle and accept requests, **manage your circle** (connected / requests / invited),
  tap a connected friend for their
  **privacy-gated trend** (today vs target, streak, 7-day adherence) or remove them,
  and share a scanned meal to a **3-day photo feed** where friends react with emojis
  (👍❤️😋🔥👏) and you receive the reactions. The story keeps the full-resolution
  photo; the AI estimate uses a downscaled copy.
- **Trends** — daily charts for calories / protein / saturated fat vs. target, each
  led by a prominent "on target X/Y days" stat. Switch between **1 / 7 / 30-day**
  windows, page to earlier windows with prev/next, and tap or drag a chart to read
  any day's value against the target.
- **Settings** — profile (editable **nickname** + sex / age / height / weight, synced
  from Apple Health with a **Sync now** button + last-synced time — edits write height
  + weight back to Health), editable goal & targets (each shows how it's calculated;
  **Use automatic** appears once the profile is reliable), account & sync (incl.
  in-app account deletion), Apple Health
  connection, language, and feedback.
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
- **Calorie budget = BMR + active + gap.** A full day's resting energy
  (Mifflin-St Jeor BMR) + the active energy you've burned (measured via Apple
  Health, or 0 when there's no reading yet / it isn't connected) + your calorie
  **gap** (the goal default — lose −500, maintain 0, gain +400 — or a custom
  value). Calories left = budget − eaten; the full-day resting part keeps it
  stable while it grows as you move. Settings shows this as the **Calorie gap
  target** and lets you edit the calorie gap, protein target, and saturated-fat
  cap directly.
- **Protein:** 1.6 g per kg of bodyweight.
- **Saturated fat:** capped at 10% of the calorie target (US Dietary Guidelines).

These are general estimates for healthy adults, **not medical advice**. In-app, a
**Sources & methodology** screen (linked from both Today and Settings, per App Store
Guideline 1.4.1) cites the references with tappable links — Mifflin-St Jeor (BMR),
the Dietary Guidelines for Americans (calorie balance + saturated fat), and the ISSN
protein position stand — alongside a medical disclaimer.

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
  (`/sync`) + in-app account deletion (`/account/delete`, App Store 5.1.1(v)),
  deployed to `ap-southeast-1`; app-side bidirectional sync of food /
  weight / profile (last-write-wins, tombstones; on sign-in / resume / edit / manual)
- [x] **Resubmitted 1.0.0 (3) to App Review** (June 12, 2026 — **Waiting for Review**):
  replied to the 1.4.1 rejection, refreshed description/promo + App Privacy answers
  (Name / Health / User ID → linked to identity), and replaced the screenshots with
  a 5-shot 6.9″ set (`store/app-store-screens/` — Today, Trends, Add, Sources &
  methodology, Settings); auto-releases on approval

- [x] **Daily meal reminders** — opt-in local notifications (breakfast 8:00 /
  lunch 12:00 / dinner 19:00 on, snack 22:00 off by default), each editable /
  toggleable / deletable + "Add reminder"; funny localized per-meal copy;
  enabled from onboarding or **Settings → Reminders**
  (`flutter_local_notifications` + `timezone`)

- [~] **Beans (in-app credit) — real StoreKit IAP wired** — 100 free Beans on
  first launch; 1 Bean per photo scan (Add screen shows "N scans left");
  iridescent pastel "jelly-bean" wallet in **Profile → Beans** with balance,
  transaction history, and a paywall of **consumable** packs **100 / 200 / 300 /
  500 / 800** (SGD 1.99 / 3.99 / 5.99 / 9.48 / 13.98). The paywall buys through
  **`in_app_purchase` / StoreKit** (`IapService` → `BeansNotifier.recordPurchase`),
  showing Apple's localized price; the five `beans_100…beans_800` products are
  **live in App Store Connect** (EN/中文, prices, review shots, available). The
  "Custom" tile and the unlimited subscription are **gone** (Apple has no arbitrary
  pricing; the sub was cut). **Screen-recordable walkthroughs** of the purchase live in
  [`beans_purchase_demo.dart`](integration_test/beans_purchase_demo.dart) (buy 200) and
  [`beans_100_demo.dart`](integration_test/beans_100_demo.dart) (recharge 100 → balance
  200); a faked store stands in for Apple's payment sheet on the sim, and the ledger row
  reads "Top-up · <price>" (no raw product id). These join the full **8-step Eva+Peter
  walkthrough** (onboarding, photo→log, the two-user Circle flow) recorded across two
  simulators. The balance is **synced to the account's
  server ledger** (`/beans` on v2) — pushed on every change, pulled on sign-in, with
  per-device signup grants collapsed (`BeansClient` + `mergeBeansLedgers`) — so it
  follows you across devices and survives a reinstall; account deletion clears it too.
  Remaining: `/iap/validate` receipt validation — see `TODO.md` §2.

- [x] **Owner metrics dashboard — moved to the web, LIVE at `foodatpeace.app/dashboard`**
  ([`store/website/dashboard/`](store/website/dashboard/index.html); prod `/metrics` dual-auth
  deployed 2026-06-17)
  → downloads / active / opens (7-day bars) / photos scanned / Beans sold / revenue /
  refunds / **AI prompt-cache hit rate + token usage** (recorded per `/analyze` call by
  `app.py` from the Anthropic `usage` block). The app still emits `open`/`scan`/`purchase` events; the **standalone web
  page** reads **live** aggregates from `GET /metrics` using a **dedicated read-only
  metrics token** (entered in-browser, never in source — kept out of the app so the
  shared `/analyze` token never ships in a web page). **All cards are now wired** —
  revenue + beans-sold are recorded server-side in [`iap.py`](backend/src/iap.py) per
  validated Apple transaction (idempotent, can't be client-faked), and `downloads` is
  folded in daily from the **App Store Connect Sales report** by a scheduled
  [`downloads.py`](backend/src/downloads.py) Lambda (needs the ASC `.p8` in SSM
  `/food-at-peace/asc-private-key`). `?demo=1` shows the layout with sample numbers.
  CORS is **locked to `https://foodatpeace.app`** (browser-only; the native app is
  unaffected), and a CloudFront viewer-request function
  ([`store/website/_cloudfront-rewrite.js`](store/website/_cloudfront-rewrite.js))
  resolves directory URLs so `…/dashboard/` works as well as `…/dashboard`. The old
  in-app 5×-tap screen was **removed**; tapping the version **10×** still reveals +
  copies this account's **user id** (sync-DB key).

**TODO (pricing — StoreKit, mind Apple's rules):**
- [x] **Beans packs** — each tier (100/200/300/500/800) is a fixed **consumable
  IAP** product (`beans_100…beans_800`) live in App Store Connect; the "Custom"
  tile was dropped (Apple has no arbitrary pricing) and the paywall buys via
  StoreKit (`in_app_purchase`). Beans are consumed in-app → Apple IAP only, no
  external payment.
- [ ] **Harden Beans IAP** — wire the **server-side ledger** (`/beans`, built on
  v2) into the client (pull on sign-in / push on append) so a balance follows the
  account, add **Restore Purchases**, and **receipt validation** (`/iap/validate`).
- [x] **Unlimited subscription — cut.** Replaced by Beans packs only (the
  auto-renewable plan and its local `subscribed` flag were removed).

**TODO (dashboard):**
- [x] **(v2)** Emit `open`/`scan`/`purchase` events + a `GET /metrics` aggregation
  endpoint. **(v3)** Dashboard moved out of the app to a standalone web page
  ([`store/website/dashboard/`](store/website/dashboard/index.html)) reading
  `GET /metrics` with a dedicated read-only token. Still TODO: `refund` events and
  **downloads** from the **App Store Connect API**.

- [x] **Circle of Food — real backend + UX (v2)** — story-style friend avatars on the
  **Trends** graph; claim a `@handle`, **share an invite universal link + QR** that
  connects both sides in one tap (`POST /circle/connect`), invite by handle,
  accept/decline **Requests**, a **Manage circle** screen (connected / requests /
  invited), tap a connected friend for their **privacy-gated** trend (today vs
  target, streak, 7-day adherence) or remove them. Plus a **3-day photo feed**: share
  a scanned meal (toggle, default on), friends react with emojis and you receive the
  reactions. Backed by `circle.py` + `posts.py` (CircleTable, PostsTable, S3 photos)
  on the v2 stack; trends/feed are gated to mutually-connected friends. The in-app
  link handler (`app_links`) + `foodatpeace://` scheme ship in build 4; the
  **universal link** needs the AASA hosted on `foodatpeace.app`
  ([`store/INVITE_LINKS.md`](store/INVITE_LINKS.md)).

**TODO (next up):**
- [ ] **Google Sign-In** — `/auth/google` mirroring `/auth/apple`
- [ ] **Recurring food** — log a repeating food entry once and have it recur
- [ ] Later: home-screen widget, barcode scan, Android

## Tech stack
- **Flutter / Dart**, iOS first (iPhone), then Android and web.
- **Riverpod** for state; **shared_preferences** for local data (behind repositories)
  and **flutter_secure_storage** for tokens/keys; **http**, **image_picker** +
  **image** (full-res story photo + downscaled analysis copy), the **health**
  package, **geolocator** (weather), **sign_in_with_apple** + **crypto** (accounts),
  **flutter_local_notifications** + **timezone** (reminders), **intl** +
  **flutter_localizations**.

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
                            AuthClient + SessionStore, SyncClient + sync engine,
                            MetricsService + AnalyticsService, CircleClient, PostsClient
    providers/              Riverpod providers
    features/               onboarding / today / add / trends / circle / settings /
                            feedback / dashboard / wallet (Beans)
    theme/ util/            theme, formatting, localized enum labels
test/                       unit + widget tests
ios/                        Runner + Runner.entitlements (HealthKit)
backend/                    AWS SAM vision proxy (Lambda, Python) — holds the Claude key
```
