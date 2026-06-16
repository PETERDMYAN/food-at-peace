# TODO — Food at Peace (`v2`)

Living list of what's shipped on `v2` vs. what's left. Device-only QA items are in
[`QA_REPORT.md`](QA_REPORT.md) §5.

## Backend topology (read before any deploy)

Production 1.0.x runs on the prod stack `food-at-peace-vision-proxy` (API
`6m19l2b025`). **v2 runs on a separate, isolated stack
`food-at-peace-vision-proxy-v2` (API `p21hoawoi5`)** — same SSM secrets, its own
tables/bucket — so v2 never touches production. See the `production-safety` skill
(`.claude/skills/production-safety/SKILL.md`) + `CLAUDE.md`. Deploy v2:

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
  `open`/`scan`; `MetricsService` reads live aggregates (`downloads`/`revenue` still
  need the ASC API / real IAP).
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
- **TestFlight** — `1.0.1 (13)` built + uploaded headlessly via the ASC API key
  (see [`PUBLISHING.md`](PUBLISHING.md) §4). (13) polishes the **Beans paywall** — a
  per-pack spinner while a purchase is in flight + a tap-guard so the same pack can't
  fire twice, and a hidden **1-Bean dev pack** (SGD 0.02) revealed by tapping the
  paywall title 10× — and makes **circle-activity notifications present as real Apple
  banners in the foreground** (`AppDelegate.willPresent` → `[.banner,.list,.sound]`).
  Since (11): **Beans follow the account**
  (the server ledger is now synced client-side — pull on sign-in, push on append) and a
  hidden **owner gesture** (tap the version **10×** to reveal + copy this account's user
  id; **5×** still opens the metrics dashboard). (11) shipped the real **StoreKit Beans
  paywall** + 100 free grant + SGD prices; unlimited subscription removed; the Circle
  notification work. Associated Domains + `foodatpeace://` scheme shipped in (4); the
  invite links are **live** on `foodatpeace.app` (§1).

Verified: Flutter 119 + backend 90 tests + 12 integration, `flutter analyze` clean. The full signed-in
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

1. **✅ `foodatpeace.app` is LIVE — invite site hosted on AWS** (2026-06-15) —
   registered via **Route53** (privacy + auto-renew) and served by **CloudFront
   `E2M22G0LAT1HKW` + ACM HTTPS** over a private S3 bucket (`foodatpeace-app-web`,
   `ap-southeast-1`, OAC). Site source: [`store/website/`](store/website/). Verified
   live: `https://foodatpeace.app/.well-known/apple-app-site-association` → `200`,
   `application/json`, no redirect; `/i/<handle>` → the smart landing (open app · App
   Store `id6777715561` · WeChat Safari hand-off); HTTP→HTTPS 301. **Remaining (you):**
   (a) click the **ICANN WHOIS-verification email** (to peter.yandongming@gmail.com,
   from Amazon Registrar) within 15 days or the domain is suspended; (b) testers
   **reinstall once** so iOS caches the AASA. **Note:** universal links open the app
   only on builds carrying the `applinks:foodatpeace.app` entitlement (TestFlight build
   4+) — the **public App Store 1.0.0 does not have it**, so until v2 ships to the App
   Store the link's download path lands on 1.0.0 (no Circle). Re-deploy the site after
   edits with: `aws s3 sync store/website s3://foodatpeace-app-web --delete` +
   `aws cloudfront create-invalidation --distribution-id E2M22G0LAT1HKW --paths '/*'`.
   Native in-WeChat open is the §6 follow-up.
2. **Beans IAP** *(in progress)* — the paywall still **dev-stubs** purchases (credits
   locally; a reinstall resets the balance). **Done:** `in_app_purchase` added +
   `IapService` ([`lib/src/data/iap_service.dart`](lib/src/data/iap_service.dart),
   consumable products `beans_100…beans_800`) + the wallet credit hook
   (`iapServiceProvider` → `BeansNotifier.recordPurchase`). **Products DONE (via the ASC
   API, no UI):** the 5 consumables `beans_100…beans_800` are created on app `6777715561`
   with **EN + 中文 localizations**, **prices** (SGD 1.99/3.99/5.99/9.48/13.98, **Singapore
   base** → auto-converts; 9.48/13.98 are Apple's nearest SGD tiers to 9.49/13.99), and
   **review screenshots** (the iridescent bean mark, not a coin), **all-territory
   availability**, and state **`READY_TO_SUBMIT`** — the whole product setup was done via
   the ASC API (the lingering "Missing Metadata" was just unset availability, fixed via
   `inAppPurchaseAvailabilities`; *not* the agreement). **ASC side fully live (2026-06-16):**
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
   (`kDebugMode`) so it never reaches TestFlight/the App Store. **Remaining:** add the
   shared secret to SSM, referral Beans (§7) and `purchase`/`refund` analytics.
3. **APNs push for circle notifications** — friend-meal alerts are currently
   surfaced locally (on app launch/resume vs a last-seen marker) and now present as
   real **Apple banners even in the foreground** (`AppDelegate.willPresent` returns
   `[.banner,.list,.sound]`), alongside the in-app banner. For *instant*
   delivery while the app is backgrounded/closed, add Apple Push: device-token
   registration, an APNs key + entitlement, and a server push from
   `posts.py` on a new post (fan out to the poster's connected friends). The
   in-app toggle ("Circle activity", in the reminders screen) already gates it.
4. **Optimise model usage** — tune the photo-analysis Claude call for cost &
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
5. **Rate-the-app prompt after 5 opens** — on the 5th app open, show the native
   App Store review prompt. Use the `in_app_review` package
   (`SKStoreReviewController` on iOS); count opens in prefs (the app already
   emits an `open` analytics event — reuse/extend that), and only request once
   (iOS rate-limits the prompt anyway). Gate behind onboarding-complete so we
   don't ask brand-new users.
6. **Enable in-WeChat open / download (WeChat Open Platform / Mini Program)** *(you —
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
7. **Referral / new-user Beans** *(growth — pairs with the invite links + §2 IAP)* —
   reward Beans through the invite loop. New users **already** get a **100-Bean welcome
   grant** on first launch (`BeanPricing.signupGrant`, granted locally in
   `BeansNotifier.build`). Add a **referral bonus**: when someone installs via an
   invite link (`foodatpeace.app/i/<handle>`) and becomes a **verified new user**
   (Sign in with Apple → first account), credit the **inviter** Beans — and optionally
   give the new user an extra welcome bonus. Needs: a **server-side Beans ledger**
   (Beans are local stubs today, see §2), invite **attribution** (carry the inviter
   handle from link → install → first sign-in, e.g. deferred deep link / pasteboard
   match against `circle.connect`), **one-reward-per-new-account** anti-abuse, and a
   "you earned N Beans 🫘" notice.
8. **Eva — a daily "life lesson" everyone follows** *(engagement)* — a built-in
   **system Circle account, Eva**, auto-added to **every** user's circle on first run /
   sign-in and **non-removable** (everyone follows her — Eva is the primary demo persona).
   Each day Eva surfaces **one fresh life-lesson aphorism** (a short "adage about life")
   in the **Circle** ("Your circle" on Trends — a pinned Eva card: her avatar + today's
   line). The line is keyed to the **user's local date**, so it flips at local midnight
   and is the **same for everyone that day** (communal): `index = localEpochDay % 100`.
   Source is a **config file of 100 Claude-generated, bilingual (EN/中文) lessons**,
   **rotated one-per-day over a 100-day cycle**, then repeats — pre-generated, so **no
   runtime model call** (offline-friendly; "fresh" = a new line each local day).
   Optionally a daily local notification ("Eva's lesson for today …") gated by the
   existing **Circle activity** toggle. **To build:** (a) **Claude generates** the 100
   bilingual lessons into the config — bundled `assets/eva_wisdom.json` (declared in
   `pubspec` assets) is the simplest first cut, *or* a server config (e.g. `/config/wisdom`
   on the v2 stack) so the list updates without an app release; (b) a `dailyWisdomProvider`
   that picks today's line by local date; (c) the pinned Eva card in the circle UI
   ([`circle_feed_screen.dart`](lib/src/features/circle/circle_feed_screen.dart) /
   Trends circle strip); (d) decide whether Eva is a **real server account** in
   `CircleTable` (shows in the friend graph, can post to the feed) or a **pure
   client-side pinned card** (no backend — simplest). Keep any bundled-config/asset
   changes backward-compatible per the `production-safety` skill.

## 📱 Device-only QA (QA_REPORT §5)

Sign in with Apple · Apple Health · local notifications · camera capture · weather
GPS · the signed-in Circle invites/feed — can't be automated on the simulator.
