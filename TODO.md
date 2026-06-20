# TODO — Food at Peace (`v2`)

Living list of what's shipped on `v2` vs. what's left. Device-only QA items are in
[`QA_REPORT.md`](QA_REPORT.md) §5.

## Backend topology (read before any deploy)

**Production cutover (2026-06-16):** the prod stack `food-at-peace-vision-proxy`
(API `6m19l2b025`) was migrated to carry the **full v2 backend** (Circle / Beans /
Iap / Metrics / Posts + their tables, plus APNs push) — additive changeset, the
existing `SyncTable` was untouched, so 1.0.0 users kept their data and the 1.0.0
contract still holds. The **public 1.0.1 release points at prod** (build with
`--dart-define-from-file=dart_defines.prod.json`). **v2 (`p21hoawoi5`) remains the
isolated dev stack** (`dart_defines.json`) — ongoing dev still targets v2, and you
still **never deploy to prod for in-progress work** (only deliberate release
cutovers, with a changeset preview). See the `production-safety` skill + `CLAUDE.md`.

**Prod deploy (2026-06-17):** additive changeset to prod (built from `v3`, changeset
previewed): `GET /metrics` dual-auth (new `x-metrics-token` for the web dashboard +
existing `x-app-token` back-compat) and `beans_25` added to `iap.py` validation. The
shared `app.py`/`auth.py`/`sync.py`/`account.py` handlers are byte-identical to the
cutover baseline → 1.0.0/1.0.1 contract intact. Verified live: `/metrics` 401 without
a token, preflight allows `x-metrics-token`. **Remaining (you):** create SSM
SecureString `/food-at-peace/metrics-token` (shared by both stacks) so the web
dashboard can authenticate.

Deploy v2:

```bash
cd backend && sam build && sam deploy --stack-name food-at-peace-vision-proxy-v2 \
  --region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3 \
  --no-confirm-changeset --parameter-overrides AppleClientId=com.foodatpeace.foodAtPeace
```

## ✅ Shipped on v2

- **Locale-aware AI analysis** — the photo estimate (name/items/portion/notes) comes
  back in the app's language (中文 → Chinese, else English). Backward-compatible (no
  `lang` field → English), so production is unaffected.
  ([`backend/src/app.py`](backend/src/app.py), [`claude_vision_client.dart`](lib/src/data/claude_vision_client.dart)).
- **Chinese (zh) App Store listing** — [`store/STORE_LISTING_zh.md`](store/STORE_LISTING_zh.md).
- **Owner analytics (real)** — `POST /event` + `GET /metrics`
  ([`backend/src/metrics.py`](backend/src/metrics.py), `MetricsTable`); the app emits
  `open`/`scan` events. `GET /metrics` now takes a **dedicated read-only
  metrics token** (`x-metrics-token`, SSM `/food-at-peace/metrics-token`) **or** the
  app token (back-compat); the standalone **web dashboard**
  ([`store/website/dashboard/`](store/website/dashboard/index.html)) reads it.
  `MetricsService` was **removed from the app**. **Revenue + beans-sold are wired** —
  recorded server-side in [`iap.py`](backend/src/iap.py) on each validated Apple
  transaction (idempotent; the client no longer emits `purchase`). **`downloads` is wired**
  too — a scheduled [`downloads.py`](backend/src/downloads.py) Lambda pulls the ASC Sales
  report daily and folds first-time downloads into the counter (idempotent per date).
  Remaining (you): store the ASC `.p8` in SSM `/food-at-peace/asc-private-key` so the
  Lambda can authenticate (key id `3FQVCHD8RS` / vendor `94423912` are template defaults).
- **Circle of Food — real backend + UX:**
  - Friend graph: claim `@handle`, invite, accept/decline, list, and privacy-gated
    friend trends ([`backend/src/circle.py`](backend/src/circle.py), `CircleTable`).
  - Your `@handle` — view / set / copy in the invite sheet.
  - **Invite universal link + QR** — share `https://foodatpeace.app/i/<handle>`
    (tappable in WeChat/WhatsApp or scanned as a QR). The receiver opens it and
    **one tap connects both sides as mutual friends** (`POST /circle/connect`).
    ([`invite_link.dart`](lib/src/data/invite_link.dart),
    [`invite_card.dart`](lib/src/features/circle/invite_card.dart),
    [`connect_sheet.dart`](lib/src/features/circle/connect_sheet.dart); in-app
    handler in [`app.dart`](lib/app.dart) via `app_links`). A `foodatpeace://`
    custom scheme is handled too (testable without the AASA — see
    [`store/INVITE_LINKS.md`](store/INVITE_LINKS.md)).
  - **Manage circle screen** — share/QR, connected (remove), incoming
    (accept/decline), and invited (cancel)
    ([`manage_friends_screen.dart`](lib/src/features/circle/manage_friends_screen.dart)).
  - **Friend-meal notifications** — when a friend shares a meal you get a
    notification + in-app banner, toggled in the reminders screen ("Circle
    activity") alongside the food reminders (same permission/service). Detected
    on launch/resume vs a last-seen marker (`circleActivityProvider.pollNew`,
    `NotificationService.show`). Local-only today — instant background delivery
    is a planned **APNs push** follow-up (see Remaining).
  - **Photo feed ("stories")** — share a scanned meal (toggle, default on) to your
    circle; friends react with emojis; you receive the reactions; posts auto-expire
    after **3 days**. ([`backend/src/posts.py`](backend/src/posts.py), `PostsTable` +
    an S3 photos bucket; [`posts_client.dart`](lib/src/data/posts_client.dart),
    [`circle_feed_screen.dart`](lib/src/features/circle/circle_feed_screen.dart)).
    The **story keeps the full-resolution photo**; the AI estimate uses a downscaled
    1024px copy.
- **Android port — builds + runs (emulator-verified) 🤖** — the Flutter app is now an Android app.
  Toolchain (JDK17 + cmdline-tools/SDK 35+36 + emulator), [`android/app/build.gradle.kts`](android/app/build.gradle.kts)
  (minSdk 26, core-library desugaring), [`android/build.gradle.kts`](android/build.gradle.kts)
  (force plugin subprojects to compileSdk 36 — `health` pinned 34), full
  [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) (internet/camera/location/
  notifications + Health Connect perms & rationale + `foodatpeace.app` App Links),
  [`MainActivity`](android/app/src/main/kotlin/com/foodatpeace/food_at_peace/MainActivity.kt) →
  `FlutterFragmentActivity` (fixes the `ComponentActivity` plugin-registration crash), platform-aware
  [`health_service_io.dart`](lib/src/data/health_service_io.dart) (no birth-date/sex on HC), Android
  launcher icon. ⏭️ **Needs the user's Google accounts:** Sign in with Apple on Android (Apple
  Services ID + `/auth/apple` audience), **FCM** push (Firebase), **Google Play Billing** + Play
  Console products mirroring `beans_*`, Play Console listing/screenshots. Health Connect runtime
  reads need the HC app on the device. (Optional: deep-verify App Links via assetlinks.json once the
  release signing key exists.)
- **Manage-circle restructure + Circle gets its own tab (build 41)** — UX-review follow-ups #1 + #3.
  Manage circle: header reads **Officials · N** (was the singular "Official account · N") with distinct
  **Coach** / **Creator** badges; the friend list is split into **Requests / Friends / Invited** (was
  one ambiguous "Your circle · N" lump); the always-on QR is **collapsed behind a "Show QR" button** so
  friends surface sooner. Circle now has its **own bottom-nav tab** (Today / Trends / Circle / Profile)
  with the strip + photo feed together — removed from the Trends screen. Pure client UI, no
  backend/shared-model change; new l10n (`navCircle`, `sectionOfficials`, `sectionFriends`,
  `sectionInvited`, `badgeCoach`, `showInviteQr`/`hideInviteQr`). ✅ build 41.
- **Lighter + cached Circle feed photos, and Eva's story spans 3 days (build 46)** — the feed felt
  empty/slow because each shared post served the **full-res 3–4 MB original** with **no caching**, so
  on cellular the images loaded slowly or timed out (looked like "no photos"). Three fixes: (1) the
  client now shares the **downscaled ~1024px copy** to `/circle/post` (the durable full-res still
  lives in the meal-photo store, keyed by entryId, for the owner's own Food story)
  ([`add_entry_screen.dart`](lib/src/features/add/add_entry_screen.dart)); (2) feed cards render with
  [`cached_network_image`](lib/src/features/circle/circle_feed_screen.dart) **keyed by `postId`** (the
  presigned S3 URL's signature rotates each fetch, so caching by URL would always miss) → instant on
  relaunch + proper placeholder/error; (3) **backfilled** the existing 10 circle-post images in S3
  (28 MB → 1 MB, 27× lighter) so the current feed is light immediately. Plus **Eva's story now spans
  the last 3 days** (one calm lesson page per day, older days dated), mirroring the 3-day feed window
  ([`openCircleStories`/`_evaLast3DaysPages`](lib/src/features/circle/circle_strip.dart)). Client +
  S3-data change, additive to prod (no Lambda code change; the `/circle/feed` + `/photo` contract is
  unchanged). New dep `cached_network_image`. Capture:
  [`integration_test/eva_3day_shots.dart`](integration_test/eva_3day_shots.dart). ✅ build 46.
- **@handle survives reinstall — recover from the server, don't re-derive (build 45)** — the handle
  defaults to a sanitised nickname ([`_deriveHandle`](lib/src/providers/providers.dart)) and is
  unique app-wide (server `register` → 409 on clash, [`circle.py`](backend/src/circle.py)), but on a
  **delete-app → sign back in** the wiped prefs made [`_ensureHandle`](lib/src/providers/providers.dart)
  **re-derive and re-register**, which could *change* a returning user's handle (drop their claimed one
  for a name-derived or random-suffixed one) — so friends' links broke. Fix: the **server is now the
  source of truth** — `_ensureHandle` first calls the new
  [`CircleClient.myHandle`](lib/src/data/circle_client.dart) (parses `me.handle` from `/circle/list`)
  and **adopts the exact handle the account already owns**; only a genuinely new account (no server
  handle) derives + claims one. Transient network error → no blind re-claim (retries next refresh).
  **Client-only, no backend change** (the server already returned `me` + enforced uniqueness), so the
  live 1.0.0/1.0.1 contract is untouched. Tests: `myHandle` parse (present/absent) in
  [`circle_client_test.dart`](test/circle_client_test.dart). ✅ build 45.
- **Eva-in-feed + nickname/handle + self-follow fix (build 44)** — three things from the Circle
  pass: (1) **Eva's daily lesson now rides at the top of the scrollable Circle feed** above every
  food-story post (new [`_EvaFeedCard`](lib/src/features/circle/circle_feed_screen.dart), shown when
  she's followed and her wisdom asset loaded; tapping opens her story) — answers "this scrollable
  feed, Eva should appear as well as all the food stories." (2) **Manage-circle handle card shows the
  nickname (display name) distinct from the @handle** — the name is what people see, the handle is the
  unique id they add you by ([`MyHandleCard`](lib/src/features/circle/invite_card.dart) now a
  `ConsumerWidget` reading `profileProvider.name`). (3) **Creator never sees "Suggested: Roro / Follow"**
  — [`followsRoroProvider`](lib/src/providers/providers.dart) now returns true when the viewer's own
  handle **is** `@roro`, so the real creator isn't prompted to follow themselves (regression test in
  [`circle_official_test.dart`](test/circle_official_test.dart)). Pure client UI, no backend/shared-model
  change. (Build 43 was an interim TestFlight upload with (1)+(2) only; build 44 supersedes it by adding
  the self-follow fix.) Capture: [`integration_test/build43_shots.dart`](integration_test/build43_shots.dart).
  ✅ build 44.
- **Circle tab polish (build 42)** — three asks: (1) **removed the "Circle" AppBar** on the Circle
  tab ([`circle_screen.dart`](lib/src/features/circle/circle_screen.dart)) — the bottom-nav tab
  already labels it, so the title bar just wasted space (SafeArea keeps content off the status bar).
  (2) **Circle feed already shows everyone's** — the server returns `[uid] + connected` authors
  ([`posts.py` `feed`](backend/src/posts.py)); a user with no connected friends just sees only their
  own, so no code change. (3) **Manage circle shows the QR by default** — replaced the collapsed
  `_InviteToggle` with the [`InviteShareCard`](lib/src/features/circle/invite_card.dart) shown
  inline. Also added an **"Archive" (history icon)** to the strip — opens *your own* food story only
  (no Eva chain), replacing the redundant feed icon ([`openMyStory(includeEva: false)`](lib/src/features/circle/circle_strip.dart)). ✅ build 42.
- **Manage-circle avatar alignment (build 40)** — the handle-card avatar was size 46 while the
  section-tile avatars are 40, so it sat larger and ~2px further left (the "name icon starts from a
  different position" report). Matched it to **size 40 + a 12px left inset** so the You/Official/peer
  icons all line up down the column. ✅ build 40.
- **Food-story photos: hydrate S3 without a thumbnail + recovered roro's shared photos (build 39)** —
  the food story only showed a photo when a local file or synced thumbnail existed, so a meal whose
  full-res is backed up in **S3 but has no thumbnail** (after a reinstall, or when the thumb was too
  big to sync) wrongly showed a caption. [`_FoodStoryPage`](lib/src/features/circle/circle_strip.dart)
  is now stateful: a photo-source meal with no local/thumb **pulls from S3** and shows the real photo
  (caption only if S3 has nothing either). **Data recovery:** matched 9 of roro's expiring
  circle-share photos (PostsTable name+calories → entry) and copied them into the durable meal store,
  so those 9 meals show again. ⚠️ **Honest gap:** the other ~11 photo-meals were logged before
  durable backup existed — phone-only originals, wiped on reinstall → unrecoverable. Forward: every
  new photo (build 30+) is S3-backed + thumbnailed, so it survives reinstall. ✅ build 39.
- **Profile-restore hardening — never push an unconfigured profile (build 38)** — belt-and-braces
  for the restore bug: [`sync_engine`](lib/src/data/sync_engine.dart) now **only pushes the profile
  once it's `isConfigured`**. A fresh-install default (even with launch-time health stats) is never
  pushed, so it can't clobber the user's real server profile before the restore is pulled — making
  reinstall (not just update) safe. (Also manually **restored roro's clobbered prod profile** via a
  direct DynamoDB put with a fresh timestamp + pinned age.) ✅ build 38.
- **Notification permission — ask + one-tap iOS Settings (build 37)** — per feedback: the in-app
  toggles stay **default-on**, but the key is actively getting the **OS permission** (independent of
  the toggle). The "Turn on notifications" card ([`_NotifyCta`](lib/src/features/circle/circle_strip.dart))
  now: **first tap → native iOS permission prompt**; once asked (iOS won't prompt again) the button
  becomes **"Open Settings"** and one tap deep-links to the app's iOS Settings page (`app-settings:`
  via `url_launcher`) to flip Notifications on. Tracks the asked-state in
  [`notificationAskedProvider`](lib/src/providers/providers.dart). ✅ build 37.
- **Profile-restore fix + Manage-circle avatar (build 36)** — two things:
  1. **Profile still didn't restore on reinstall even on prod.** Meals/weight came back but the
     profile (name, targets) stayed blank. Root cause: a fresh device's local profile is
     *unconfigured*, but launch-time [`refreshFromHealth()`](lib/src/providers/providers.dart)
     fills HealthKit stats and `save()` stamps `updatedAt = now` — which beat the user's real
     (configured) **server** profile (earlier timestamp) under plain last-write-wins, discarding it.
     Meals restored fine because there's no local default to out-timestamp them. Fix:
     [`mergeProfile`](lib/src/data/sync_engine.dart) now has a **restore guard** — a *configured*
     server profile always wins over an *unconfigured* local one (then normal LWW). Tests:
     `sync_merge_test.dart` (+2: restore-over-fresh, and don't-clobber-configured-local).
  2. **Manage circle → your own avatar** now appears on the handle card and is **tappable to open
     your story** (grey "seen" ring once viewed) — [`MyHandleCard`](lib/src/features/circle/invite_card.dart)
     + a reusable [`openMyStory`](lib/src/features/circle/circle_strip.dart) (also DRYs the strip's
     You/Eva taps). ✅ build 36 (prod). Capture: `integration_test/circle_strip_shots.dart`.
- **Data-restore fix — main app now points at PROD (build 35)** — a returning user (deleted +
  reinstalled, signed back in with Apple) saw all their info **blank**. Root cause: this session's
  TestFlight builds 33/34 were built with `dart_defines.json` (**v2** `p21hoawoi5`, near-empty)
  instead of `dart_defines.prod.json` (**prod** `6m19l2b025`), where the real data lives — verified
  **26 rows on prod** (profile + 24 meals + weight) vs **1 empty profile on v2**. **No data lost.**
  Build 35 = build 34's code rebuilt against prod (defines verified: `PROXY_BASE_URL=6m19l2b025`);
  reinstalling restores everything. Guardrail added to CLAUDE.md (build target ↔ which dart_defines)
  + memory `dart-defines-prod-vs-v2`. ⚠️ **Release check:** confirm the App Store 1.0.2 binary
  (build 28, in review) points at prod before releasing — couldn't verify it retroactively; safest
  is to submit a prod-verified build (35+) for the public release.
- **Circle UX pass + notification CTA (build 34)** — a new-user review found four things:
  1. **Story "seen" rings** — a viewed story now shows a grey ring instead of the colourful one
     ([`StoryAvatar.seen`](lib/src/widgets/story_avatar.dart), [`seenStoriesProvider`](lib/src/providers/providers.dart)
     + the viewer's `onStoryViewed` callback). Keys embed the content (newest meal + count / the
     day's Eva lesson) so fresh content resets the ring to unseen.
  2. **Roro moved left of the Add icon** — grouped with the official accounts in the strip
     (You · Eva · Roro · ＋ · peers), via a roro/peers split in [`circle_strip.dart`](lib/src/features/circle/circle_strip.dart).
  3. **Unfollow wording unified** — official accounts (Eva, Roro) **and** peers all say
     **"Unfollow"** now (Manage/trend previously said "Remove from circle", and Roro used a
     remove-icon while Eva said "Unfollow"). Consistent across the feed ⋯ menu, Manage circle,
     and the friend-trend sheet (`feedUnfollow*` strings everywhere).
  4. **Strong notification CTA** — defaulting circle-notify on is meaningless without OS
     permission, so the strip shows a prominent **"Turn on notifications"** card when notify is on
     but permission isn't granted ([`notificationsAllowedProvider`](lib/src/providers/providers.dart)
     + [`NotificationService.hasPermission`](lib/src/data/notification_service.dart)); tapping
     requests permission, re-checked on resume. Capture: `integration_test/circle_strip_shots.dart`.
  ✅ **Uploaded to TestFlight (build 34).**
- **New skill — `new-user-experience`** — `.claude/skills/new-user-experience/SKILL.md`: after every
  user-facing change, check the fresh-onboard path (empty data, no permissions, just signed in /
  signed out) — empty states, permission CTAs, sensible defaults — before calling it done.
- **IAP purchase feedback fix (build 33)** — after Apple's payment sheet closed, the only
  feedback was a tiny per-tile spinner while the receipt validated server-side (1–5s), so a paid
  purchase felt like *"I paid but nothing happened"*. The Beans paywall
  ([`beans_screen.dart`](lib/src/features/wallet/beans_screen.dart)) now shows a **full-sheet
  "Processing your payment…"** state (back-dismiss blocked while in flight) and, once the Beans are
  actually credited, a **success view** (green check + "Added N Beans" + new balance) that lingers
  ~1.5 s before auto-closing. [`iap_service.dart`](lib/src/data/iap_service.dart) now **awaits the
  credit before resolving `buy()`** (guarded — Apple already charged, so a credit hiccup still
  resolves), so success only shows once the balance is up to date. l10n EN+中文
  (`iapProcessingTitle`/`iapProcessingBody`/`iapSuccessBody`/`iapNewBalance`). Tests:
  `beans_paywall_test.dart` (3, incl. processing→success). Capture harness:
  `integration_test/iap_shots_test.dart`. ✅ **Uploaded to TestFlight (build 33).**
- **Official Circle accounts — Eva + Roro (build 31)** — Eva (built-in AI coach) is now a
  followable Official member ([`evaFollowedProvider`](lib/src/providers/providers.dart), default
  **followed**): her daily-lesson story in the strip
  ([`circle_strip.dart`](lib/src/features/circle/circle_strip.dart)); unfollow → she moves to a new
  **"Suggested to follow"** section in [`manage_friends_screen.dart`](lib/src/features/circle/manage_friends_screen.dart).
  Roro = the creator's **real** @handle ([`kRoroHandle`](lib/src/providers/providers.dart)),
  **recommended only** (opt-in one-tap `connect('roro')` — never auto-followed, so no mutual
  data-sharing without consent; `followsRoroProvider` hides the card once connected). Both wear an
  **Official** badge. **Manage circle is now 3 sections (build 32):** *Official account* (Eva +
  @roro once followed), *Suggested to follow* (the rest), *Your circle* (real peers) — and the
  "circle is empty" message lives only under *Your circle*. First-party, NOT fabricated peers
  (consistent with the no-dummy-data skill:
  Eva/Roro are real product entities). Tests: `circle_official_test.dart` (6). ⚠️ **@roro must be a
  claimed account** for the Follow to connect (otherwise it shows "couldn't follow" and the card
  stays). Build 31 also ships the profile-photo S3 durability.
- **Meal-photo durability fix (next build, 29)** — the synced photo copy
  ([`encodeMealThumb`](lib/src/data/meal_photos.dart)) now **adaptively shrinks** (size + quality
  ladder) so its **base64 string** always stays under DynamoDB's 400 KB row limit. Root cause: a
  detailed 1080px photo's base64 is ~33% bigger than the JPEG and could exceed 400 KB; the old
  test measured the *decoded* bytes (a 33% under-count) on a *solid-colour* image (compresses to
  nothing), so it never caught it. Worse, [`sync.py`](backend/src/sync.py) put each record in one
  top-level try/except, so a single oversized row **500'd the entire push** (blocking ALL sync) →
  after a reinstall (device-local original gone) the photo vanished. Tests now assert the **base64
  length** under cap on a **detailed** image. ✅ **Server guard (deploying v2→prod):**
  [`sync.py` `_apply_one`](backend/src/sync.py) now catches an oversized-row write, **drops the
  un-storable `photoThumb` and saves the meal** (or skips just that one row) instead of 500-ing
  the whole push — unblocks already-stuck users the client fix can't reach. Tests:
  `test_oversized_photo_saves_meal_without_photo_not_500` + `_skipped_not_500`. ⏭️ **Proper fix
  (in progress):** S3 full-res per-user photo store so large photos keep full quality.
  ✅ **Backend built + on v2:** new [`mealphotos.py`](backend/src/mealphotos.py) Lambda +
  no-TTL `MealPhotosBucket` + routes `/photo/put-url|get-urls|delete` (presigned PUT/GET so
  full-res bypasses Lambda's 6 MB + DynamoDB's 400 KB limits; session-gated, per-user
  `meal/<uid>/<entryId>.jpg`). Tests: `test_mealphotos.py` (7). ✅ **Client done (build 30):**
  [`meal_photo_store.dart`](lib/src/data/meal_photo_store.dart) uploads the full-res on save
  ([`add_entry_screen`](lib/src/features/add/add_entry_screen.dart)); the Food story
  ([`_HeroPhoto`](lib/src/features/circle/circle_strip.dart)) shows the synced thumb instantly and
  upgrades to the S3 full-res, hydrating the local cache on a new device / after a reinstall. All
  best-effort → falls back to the thumb. Smoke-tested on v2 (routes return 401 unauth). Prod
  deploy + build 30 done.
- **Profile photo now durable too** — was the only remaining local-only *content* (lost on
  reinstall, like meal photos were). [`profile_photo.dart`](lib/src/data/profile_photo.dart) now
  reuses the same S3 store (reserved id `__profile__`): uploaded on set, **restored from the cloud
  on sign-in**, deleted on clear. No backend change (the endpoint accepts any sanitized id). Found
  via a full local-vs-synced audit — everything else of value (food, weight, profile fields, Beans
  ledger, @handle/friends/circle) is already server-backed; the rest is just preferences that reset.
- **TestFlight / App Store** — **`main` build `1.0.2 (28)` → submitting to App Store** (2026-06-18,
  prod backend, `/tmp/fap_rec/build28.sh`). (28) **Circle post moderation — Apple Guideline 1.2
  (UGC safety)**: every Circle feed post (others', not your own) now has a **⋯ menu** with
  **Report** and **Unfollow**
  ([`circle_feed_screen.dart`](lib/src/features/circle/circle_feed_screen.dart)). Report opens a
  reason picker (spam / nudity / harassment / violence / other) and **hides the post for the
  reporter immediately** via a persisted [`hiddenPostsProvider`](lib/src/providers/providers.dart)
  (`circle_hidden_posts`), with a "we review & remove within 24h" confirmation. Unfollow confirms,
  then **removes the friend both ways** through the existing live `/circle/remove`
  (`circleProvider.remove(post.authorId)`) and hides their post. **Client-side only — no backend
  change** (uses the already-live remove endpoint), so it's prod-safe. Tests:
  `test/circle_feed_menu_test.dart` + `test/circle_hidden_posts_test.dart`. (27) **fix: no seeded
  fake friends for real users**.
  `CircleNotifier` no longer writes `Friend.seed()` (Mia/Jay/Sara/Ben) for the signed-out state;
  a one-time migration (`_dropLegacySeededFriends`) strips those ids from anyone who already
  cached them — new/upgrading users start with an **empty circle** (You + Eva + Add). Shipped in
  live 1.0.1, so it rolls out with this 1.0.2 submission. (26) **Circle activity notifications on
  by default**:
  `circleNotifyProvider` now defaults **true** (was opt-in); the OS notification permission is
  requested **lazily** the first time there's real circle activity
  ([`home_shell._checkCircleActivity`](lib/src/features/home/home_shell.dart)) so the toggle
  isn't "on but silent". An explicit off still persists. (25) **Data sources + active-energy
  priority**:
  Settings ▸ **Data sources** ([`data_sources_screen.dart`](lib/src/features/settings/data_sources_screen.dart))
  lists each device writing active energy to Apple Health (Garmin Connect / Apple Watch /
  iPhone — discovered via `HealthService.energySources()`) and lets you pick which **takes
  priority**; the choice persists (`energySourcePriorityProvider`) and `readEnergyOut`
  honors it (pure, tested `sumActiveEnergy`: preferred source wins when it has data, else
  combine). A *fully direct* Garmin link is out of scope (needs Garmin's Developer Program +
  a backend); Garmin still flows via Apple Health. (24) **"Take daily" recurring foods +
  story-delete fix**:
  - A [`FoodEntry.recurring`](lib/src/models/food_entry.dart) flag marks a supplement / daily
    staple; logged **once**, it's counted on **every** day from its start (Today list + daily
    summary via `entriesForSelectedDayProvider` (sorted into its time-of-day slot per day), and
    Trends), shown with a **Daily** badge. Set it by **tapping a Today (今日饮食) item** → a sheet
    to toggle it (`FoodEntriesNotifier.setRecurring`). **(24) removed the post-save prompt** —
    build 23 asked after every save; per user feedback it's now Today-item-only.
  - **Deleting a Food-story page no longer deletes the log entry** — it now sets
    [`hiddenFromStory`](lib/src/models/food_entry.dart) (`hideFromStory`), so the meal stays in
    Today/Trends. (Earlier build 19 wrongly soft-deleted the log.)
  Both fields additive + backward-compatible (old clients treat as one-off / visible).
  (22) was **story chaining + photo resolution**: the
  full-screen viewer is now a **tray** ([`story_viewer.dart`](lib/src/features/circle/story_viewer.dart)
  `showStories`/`Story`) — advancing past the last page of *your* food story **rolls into
  Eva's story** (and back past the first returns), instead of quitting; the progress bar
  resets per person. And the **synced photo thumbnail is now 1080px** (was 480px;
  [`meal_photos.dart`](lib/src/data/meal_photos.dart) `encodeMealThumb`) so synced /
  reinstalled entries look as crisp as freshly-scanned ones, with `FilterQuality.medium` on
  the story image. (21) added **left/right swipe navigation** to the story viewer
  (`onHorizontalDragEnd`: swipe → next, ← previous; tap-to-advance still works). (20)
  **fixes "I don't see the food photo, only nutrient info"**: meal photos were **device-local only and never synced**, so any food-story entry that
  arrived via cloud sync (e.g. meals logged on the demo simulators) or predated photo capture
  fell back to the nutrient card. Now a **small base64 thumbnail rides on the `FoodEntry`**
  ([`food_entry.dart`](lib/src/models/food_entry.dart) `photoThumb`, `encodeMealThumb` in
  [`meal_photos.dart`](lib/src/data/meal_photos.dart)) so the photo **syncs across devices /
  survives a reinstall**; the story prefers the full-res local original and falls back to the
  thumb. **No backend deploy** — it rides inside the sync `data` blob (opaque JSON), additive +
  backward-compatible with the live 1.0.x contract. (19) was the **story polish batch**: the **Food story** is
  now **photo-hero** (the meal photo fills the frame; calories/macros are an Instagram-style
  **caption**), **Eva's lesson is a Calm-style scene** (per-lesson gradient + glow across the
  100 lessons, [`circle_strip.dart`](lib/src/features/circle/circle_strip.dart) `_calmScenes`),
  the food story now spans the **last 7 days** (archive, newest-first) with a **per-story
  delete** (confirm → removes the log entry + its meal photo), and a **profile photo**
  ([`profile_photo.dart`](lib/src/data/profile_photo.dart)) you set in Settings (camera-badge
  avatar) that shows in the circle **You** avatar + your story header. (18) added the
  full-screen Food story + per-entry meal photos ([`meal_photos.dart`](lib/src/data/meal_photos.dart),
  local `<docs>/meal_photos/<id>.jpg`). (17) was the first
  Circle-stories cut + Haiku. Earlier builds —
  prod backend, `/tmp/fap_rec/build17.sh` — added the **Circle stories** rework (Eva + You as
  tappable stories, lesson attribution) and the **Haiku** photo-analysis model (direct-key
  `defaultModel`); rides on (16)'s rate-the-app prompt + `purchase` analytics + `beans_25`.
  Becomes the 1.0.2 submission after 1.0.1 clears review. (`beans_25` server validation +
  the v3 `iap.py` are already live on prod.) Earlier cuts: (16) Eva card + rate-app +
  analytics; (15) Eva + `beans_25`.
  Earlier: `1.0.1 (14)` built against **prod**
  (`--dart-define-from-file=dart_defines.prod.json`) + uploaded via the ASC API key,
  and submitted to App Store review on 2026-06-16 (first public v2 release; all 5 Beans
  consumables `beans_100…beans_800` attached, **auto-release on approval**). Then pulled
  back, **refreshed the store metadata, and resubmitted (2026-06-16 — "Waiting for
  Review")**: a generated **bilingual 6-shot screenshot set** (EN `store/app-store-screens/`
  + 简体中文 `…-zh/`, 1320×2868: Today · Circle · Scan · Trends · Beans · Settings, via
  [`integration_test/store_screenshots.dart`](integration_test/store_screenshots.dart)),
  Circle + Beans added to the EN/中文 descriptions, an EN subtitle, and a new **简体中文
  localization** with the CN app name **食之安**. Also localized the Circle post card
  (`feedYou`/`feedSomeone` + `kcalValue`) so the feed reads fully in 中文. (14) adds
  **server-side IAP receipt validation** (`/iap/validate`, §1), **APNs background push**
  for circle activity (request / accept / shared-meal / reaction → real Apple banners
  even when the app is closed; key `D2665A2D4P`, [`backend/src/apns.py`](backend/src/apns.py)
  + `/circle/register-device`, token captured in `AppDelegate` → `shared_preferences`),
  and **gates the hidden 1-Bean dev pack to debug builds**. (13) added the Beans-paywall
  spinner + tap-guard and foreground banners (`AppDelegate.willPresent`).
  Since (11): **Beans follow the account**
  (the server ledger is now synced client-side — pull on sign-in, push on append) and a
  hidden **owner gesture** (tap the version **10×** to reveal + copy this account's user
  id). The in-app **metrics dashboard was removed** in v3 → it's now a **standalone web
  page** ([`store/website/dashboard/`](store/website/dashboard/index.html)) reading
  `GET /metrics` with a dedicated read-only token. (11) shipped the real **StoreKit Beans
  paywall** + 100 free grant + SGD prices; unlimited subscription removed; the Circle
  notification work. Associated Domains + `foodatpeace://` scheme shipped in (4); the
  invite links are **live** on `foodatpeace.app`.

Verified: Flutter 119 + backend 95 tests + 12 integration, `flutter analyze` clean. The full signed-in
Circle flow was exercised **in-app on two simulators** against the live v2 backend
(injected session tokens, since Apple sign-in can't run on a sim): user A scans +
posts a meal → user B opens A's invite → one-tap mutual connect → B's feed shows A's
photo → B reacts ❤️ → A receives it (all confirmed server-side too). Driver:
[`integration_test/circle_two_user_demo.dart`](integration_test/circle_two_user_demo.dart).

A full **8-step Eva+Peter walkthrough video** (2026-06-16) records end-to-end on the two
simulators, adding screen-recordable single-user drivers:
[`onboarding_demo.dart`](integration_test/onboarding_demo.dart) (Apple ID + Health injected
exactly as the app consumes them), [`photo_log_demo.dart`](integration_test/photo_log_demo.dart)
(scan → 420 kcal → log), and [`beans_100_demo.dart`](integration_test/beans_100_demo.dart)
(recharge 100). The shared demo photo ([`demo_food_image.dart`](integration_test/demo_food_image.dart))
is now a single plated dish so the AI estimate reads cleanly (~420 kcal, not a 2850 kcal grocery spread).

## 🚧 Remaining

1. **Beans IAP** *(in progress)* — the paywall still **dev-stubs** purchases (credits
   locally; a reinstall resets the balance). **Done:** `in_app_purchase` added +
   `IapService` ([`lib/src/data/iap_service.dart`](lib/src/data/iap_service.dart),
   consumable products `beans_100…beans_800`) + the wallet credit hook
   (`iapServiceProvider` → `BeansNotifier.recordPurchase`). **Products DONE (via the ASC
   API, no UI):** the 5 consumables `beans_100…beans_800` are created on app `6777715561`
   with **EN + 中文 localizations**, **prices** (SGD 1.99/3.99/5.99/9.48/13.98, **Singapore
   base** → auto-converts; 9.48/13.98 are Apple's nearest SGD tiers to 9.49/13.99), and
   **review screenshots** (the iridescent bean mark, not a coin), **all-territory
   availability**, and (until 2026-06-16) state **`READY_TO_SUBMIT`** — the whole product
   setup was done via the ASC API (the lingering "Missing Metadata" was just unset
   availability, fixed via `inAppPurchaseAvailabilities`; *not* the agreement). **All 5 are
   now attached to version 1.0.1 and IN REVIEW** (submitted 2026-06-16 — first IAP must ride
   a version). **ASC side fully live (2026-06-16):**
   Paid Apps agreement, bank account (UOB, SGD), and Singapore tax form are all **Active**.
   Only remaining user step: add a **Sandbox tester** (Users and Access → Sandbox) before
   on-device purchase testing — not blocking. **Paywall switched (done):**
   `beans_screen.dart` now buys via `IapService.buy` (StoreKit), shows the **localized
   store price** (falls back to the indicative SGD), the **"Custom" tile is gone** (Apple
   can't price arbitrary amounts), and the integration tests inject a **fake store** so
   the purchase flow runs on the sim (8/8 green). A slowed-down, **screen-recordable**
   walkthrough of a buy is in
   [`integration_test/beans_purchase_demo.dart`](integration_test/beans_purchase_demo.dart)
   (wallet 100 → Top up → buy 200 → balance 300 + ledger row; a faked store stands in for
   Apple's payment sheet on the sim — the real sheet was already exercised on-device).
   **Ledger polish:** a purchased row no longer renders the raw StoreKit product id
   (`beans_100`) — it shows just "Top-up · <price>" (`recordPurchase` dropped the
   product-id `note`, [`providers.dart`](lib/src/providers/providers.dart)).
   **Phase 2 (Beans follow the account — DONE):** an isolated, append-only `/beans`
   ledger on v2 (GET pulls, POST appends; idempotent by txn id; bearer-auth; own
   `BeansTable`; **one signup grant per account** enforced server-side),
   [`backend/src/beans.py`](backend/src/beans.py). The client
   [`BeansClient`](lib/src/data/beans_client.dart) + `BeansNotifier` reconcile on sign-in
   and after every append (push local → adopt the merged server ledger; per-device signup
   grants collapsed via `mergeBeansLedgers`), so a balance follows the account across
   devices and survives a reinstall. `account.py` now also clears `BeansTable` on account
   deletion. Verified live: roro's seeded 80-Bean purchase is returned by `GET /beans` for
   her account. **Phase 3 (receipt validation — DONE):** `POST /iap/validate`
   ([`backend/src/iap.py`](backend/src/iap.py)) verifies the App Store receipt with the
   shared secret (SSM `/food-at-peace/iap-shared-secret`) and credits Beans server-side,
   **idempotent by Apple transaction id**; the client validates after a StoreKit purchase
   and adopts the server ledger, falling back to a local credit when the secret isn't set
   so nothing breaks (`BeansClient.validateIap`, `BeansNotifier.creditPurchase`). The
   **hidden 1-Bean dev pack** (free local credit) is gated to **debug builds only**
   (`kDebugMode`) so it never reaches TestFlight/the App Store. **The Apple shared secret
   is now live in SSM** (`/food-at-peace/iap-shared-secret`, SecureString, ap-southeast-1,
   2026-06-16), so receipt validation runs server-side (no redeploy — read per cold start).
   **Remaining:** referral Beans (§4). ✅ **`purchase` analytics** now emitted on every
   Beans purchase (`BeansNotifier.creditPurchase` → `AnalyticsService.emit('purchase',
   {beans, product})`, on `v3`). **`refund` analytics** is deferred — refunds aren't
   client-observable; they'd need **App Store Server Notifications v2** (a server webhook),
   so that's a separate backend task.
   **Web recharge (Stripe) — NEW, live on prod + v2 (this session):** a standalone
   top-up page at **`foodatpeace.app/recharge`** that credits the same `/beans`
   ledger via Stripe — no Apple cut, and a path for **Android / web** users who
   have no StoreKit. New Lambda [`backend/src/recharge.py`](backend/src/recharge.py):
   `POST /recharge/checkout` (bearer-auth) creates a Stripe Checkout session;
   `POST /recharge/webhook` verifies Stripe's HMAC signature and credits Beans
   **server-side, idempotent by Stripe session id** — same fraud model as
   [`iap.py`](backend/src/iap.py) (a forged request can't mint Beans; Beans are
   recomputed from `productId`, never trusted from client metadata). Hand-rolled
   Stripe (urllib + `hmac`) so nothing is added to the shared `src/requirements.txt`.
   Page [`store/website/recharge/index.html`](store/website/recharge/index.html) is
   bilingual EN/中文, identifies the account via **Sign in with Apple on the web** (reusing
   `POST /auth/apple` — Apple's `sub` matches the native app, so the web login hits the
   same ledger; a paste-token field stays under *Advanced* for testing), so there's
   **no app change** and the App Store app is untouched. It shows the live balance + the
   6 packs, redirects to Stripe Checkout, and polls `/beans` on return. Needs a one-time
   Apple **Services ID** (`com.foodatpeace.web`, in **prod's + v2's** `APPLE_CLIENT_ID`) + a
   domain-association file. Tests:
   [`backend/tests/test_recharge.py`](backend/tests/test_recharge.py) (12, incl.
   signature verify, idempotency, unpaid / other-event ignored). Setup + deploy steps
   in [`store/RECHARGE.md`](store/RECHARGE.md). ⚠️ **App Store 3.1.1:** keep this a
   *standalone* page — do **not** add an in-app button to it, or the iOS app risks
   rejection (in-app buying stays on StoreKit). **Remaining (you):** (a) put the Stripe
   **secret key** in SSM `/food-at-peace/stripe-secret-key` and (b) the **webhook signing
   secret** in `/food-at-peace/stripe-webhook-secret` (after registering
   `<api>/recharge/webhook` in the Stripe dashboard for event
   `checkout.session.completed`); until both exist, `/checkout` returns
   `{configured:false}` and the page shows a graceful "not on yet". ✅ **Cut over to prod
   2026-06-19** — additive changeset (every shared handler byte-identical except a
   backward-compatible `auth.py` audience tweak; 1.0.0 contract verified intact via a
   no-execute changeset review + post-deploy probes), Services ID added to prod's
   `APPLE_CLIENT_ID`, and the page's `DEFAULT_BASE` flipped to prod + republished. Still
   needed before charging: Stripe keys + the Apple Services ID/domain file.
2. **Optimise model usage** — tune the photo-analysis Claude call for cost &
   latency. The model is server-side via the `MODEL` env var (default
   `claude-sonnet-4-6`), so it's swappable without an app update. Levers to
   evaluate: try a **cheaper/faster tier** (e.g. Haiku) and measure estimate
   quality vs. Sonnet; tighten the system prompt / `max_tokens`; lean harder on
   **prompt caching** (the system block is already cached — verify cache hits);
   **downscale the analysis image** further (currently 1024px) and check accuracy;
   short-circuit obvious non-food photos. Measure $/scan + p50/p95 latency before
   and after. Keep the request **backward-compatible** with the shipped 1.0.0 app
   (see the `production-safety` skill) and keep the Dart/Python request builders in
   sync. Mirrored in tasks.
   **Progress (2026-06-17):** **measurement wired** — `app.py` records the Anthropic
   `usage` block (input/output/cache-read/cache-write tokens + hit counts) into the
   metrics counter per call; the **owner dashboard now shows AI cache hit-rate + token
   usage**. **Haiku-vs-Sonnet spot-check** (5 photos via the v2 stack): Haiku tracked
   Sonnet within ~5–16% on everyday meals (±macros), diverged on a whole-pizza portion
   (+38%), both correctly refused a non-food image, Haiku ~2× faster + ~3–4× cheaper.
   **Decision (2026-06-18): switched to `claude-haiku-4-5-20251001`** for ~3–4× lower
   cost + ~2× faster scans (spot-check kept everyday-meal accuracy). Server-controlled
   `Model` param — flipped on **prod + v2** (affects all client versions on the proxy
   path, incl. live 1.0.0, with no app update) and set as the template default; the
   direct-key path's `defaultModel` also bumped to Haiku (ships build 17+). Instantly
   revertible by setting `Model` back to `claude-sonnet-4-6`. Watch the live edit-rate;
   escalate to Sonnet on low-confidence/large-portion cases if it slips. **Caching finding:** the
   measurement showed prompt caching is **currently inert** — the cached prefix
   (system+tools) is **~400 tokens, below Anthropic's ~1024-token cache minimum**, so
   `cache_control` is a no-op (0 read/write). It's also a non-lever here (the ~1.4k-token
   image dominates input and is uncacheable). Left in place (harmless; auto-engages if the
   prefix grows); dashboard shows "off" when not engaging. Still open: tighten
   prompt/`max_tokens`, optional confidence-based Haiku→Sonnet escalation.
3. **Enable in-WeChat open / download (WeChat Open Platform / Mini Program)** *(you —
   needs a verified WeChat account)* — WeChat's in-app browser **blocks iOS Universal
   Links and App Store redirects**, so a shared `foodatpeace.app/i/<handle>` can't
   natively open or install the app inside WeChat; the landing page can only fall back
   to a "tap ··· → Open in Safari" guide. To open/download **without leaving WeChat**,
   register on the **WeChat Open Platform (微信开放平台)**:
   - **Mobile App** registration → obtain a WeChat `AppID`, integrate the WeChat
     OpenSDK, and register the app's **Universal Link** so WeChat permits it to launch
     the app directly from a chat (`weixin://` / `LSApplicationQueriesSchemes`).
   - and/or a **Mini Program (小程序)** that renders the invite natively (inviter card +
     "Open app / Download" CTA) and launches the app via `launchApplication` / the
     Universal Link.
   - Prereq: a **verified business entity** (营业执照 — China-registered company, or a
     third-party agent), ~300 RMB/yr verification. Then add the WeChat SDK + a new iOS
     build. Until then, the landing page's Safari hand-off is the supported WeChat path.
4. **Referral / new-user Beans** *(growth — pairs with the invite links + §1 IAP)* —
   reward Beans through the invite loop. New users **already** get a **100-Bean welcome
   grant** on first launch (`BeanPricing.signupGrant`, granted locally in
   `BeansNotifier.build`). Add a **referral bonus**: when someone installs via an
   invite link (`foodatpeace.app/i/<handle>`) and becomes a **verified new user**
   (Sign in with Apple → first account), credit the **inviter** Beans — and optionally
   give the new user an extra welcome bonus. Needs: a **server-side Beans ledger**
   (Beans are local stubs today, see §1), invite **attribution** (carry the inviter
   handle from link → install → first sign-in, e.g. deferred deep link / pasteboard
   match against `circle.connect`), **one-reward-per-new-account** anti-abuse, and a
   "you earned N Beans 🫘" notice.
## 🔭 Deferred / later (not active dev)

Shipped/complete — only optional or release-time tails remain:
- **Eva story (shipped on `v3`)** — optional polish, none required: Eva as a real server
  account in `CircleTable`; server-updatable lessons (`/config/wisdom`) so the list
  refreshes without an app release; a daily lesson notification (gated by the *Circle
  activity* toggle); a **friend-visible** profile photo (S3 upload + URL, mirroring
  `posts.py` — it's local-only today); real licensed scene photography (today
  `_calmScenes` are procedural gradients).
- **`beans_25` IAP (code done on `v3` + already live on prod)** — just **attach the ASC
  product** (Ready to Submit, Apple ID 6780952980) **to the 1.0.2 submission** once 1.0.1
  clears review. The prod `iap.py` validation is already live (additive, backward-compatible
  — doesn't touch the 1.0.0/v2 contract).

## 📱 Device-only QA (QA_REPORT §5)

Sign in with Apple · Apple Health · local notifications · camera capture · weather
GPS · the signed-in Circle invites/feed — can't be automated on the simulator.

Carried over from now-removed Remaining items (infra/logic done & verified 2026-06-18;
only the on-device step is left):
- **Invite universal links** — testers **reinstall once** so iOS caches the AASA, then
  tapping `foodatpeace.app/i/<handle>` opens the app. Universal links need the
  `applinks:foodatpeace.app` entitlement (TestFlight build 4+); the public App Store
  1.0.0 lacks it, so its links land on the App Store until v2 ships publicly. Site +
  AASA verified live; chain (AASA appID, entitlement, `kInviteDomain`, landing page) all
  correct.
- **APNs background push** — verify true end-to-end delivery (server → Apple → a
  backgrounded device) on a **physical device**: a sim has no real APNs token, so the
  register-device → push loop can't run there. Server signing/triggers + the payload
  shape are unit-verified (`test_push`/`test_circle`/`test_posts`); the sim accepts the
  exact payload. Push copy is English-only for now.
