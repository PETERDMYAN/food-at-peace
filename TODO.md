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
- **TestFlight / App Store** — **`v3` build `1.0.2 (17)` uploaded to TestFlight** (2026-06-18,
  prod backend, `/tmp/fap_rec/build17.sh`) — adds the **Circle stories** rework (Eva + You as
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
  **server-side IAP receipt validation** (`/iap/validate`, §2), **APNs background push**
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
  invite links are **live** on `foodatpeace.app` (§1).

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

1. **✅ `foodatpeace.app` is LIVE — invite site hosted on AWS** (2026-06-15) —
   registered via **Route53** (privacy + auto-renew) and served by **CloudFront
   `E2M22G0LAT1HKW` + ACM HTTPS** over a private S3 bucket (`foodatpeace-app-web`,
   `ap-southeast-1`, OAC). Site source: [`store/website/`](store/website/). Verified
   live: `https://foodatpeace.app/.well-known/apple-app-site-association` → `200`,
   `application/json`, no redirect; `/i/<handle>` → the smart landing (open app · App
   Store `id6777715561` · WeChat Safari hand-off); HTTP→HTTPS 301. **(a) ICANN
   WHOIS-verification — ✅ DONE (2026-06-17):** email verified; Route53 registrar status
   is clean (`clientTransferProhibited` only — no hold/pending), expiry 2027-06-15, site
   resolves 200 → not suspended. **Remaining (you):** (b) testers
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
   **Remaining:** referral Beans (§7). ✅ **`purchase` analytics** now emitted on every
   Beans purchase (`BeansNotifier.creditPurchase` → `AnalyticsService.emit('purchase',
   {beans, product})`, on `v3`). **`refund` analytics** is deferred — refunds aren't
   client-observable; they'd need **App Store Server Notifications v2** (a server webhook),
   so that's a separate backend task.
3. **APNs push for circle notifications — DONE (needs on-device verification).**
   Local notifications already fire on launch/resume + present as foreground Apple
   banners; **build 14 adds true background Apple Push**: APNs key `D2665A2D4P`
   (Sandbox & Production, team-scoped) in SSM (`apns-key`/`apns-key-id`); the client
   registers for remote notifications, `AppDelegate` writes the token to
   `shared_preferences`, and `home_shell` POSTs it to `/circle/register-device`; the
   server pushes via [`backend/src/apns.py`](backend/src/apns.py) (pure-Python ES256
   JWT via `ecdsa` + HTTP/2 via `httpx`, best-effort) on **invite / accept**
   ([`circle.py`](backend/src/circle.py)) and **shared-meal / reaction**
   ([`posts.py`](backend/src/posts.py)). aps-environment entitlement added; Push
   capability auto-provisioned in the build. **Remaining:** verify end-to-end on a
   physical device (couldn't be tested in the sim); push copy is English-only for now.
   The in-app toggle ("Circle activity") still gates the in-app banner.
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
5. **Rate-the-app prompt after 5 opens — ✅ DONE on `v3`** (2026-06-17). The native
   `SKStoreReviewController` prompt fires once, on the 5th app open, via the
   `in_app_review` package. [`app_review_service.dart`](lib/src/data/app_review_service.dart):
   an `AppReviewService` interface (so tests inject a fake) + `AppReviewPrompter` that
   counts opens in prefs (`app_open_count`) and asks once (`app_review_requested`).
   Driven from [`home_shell.dart`](lib/src/features/home/home_shell.dart) `initState` —
   the home shell only mounts post-onboarding, so new users aren't asked. Unit-tested
   (asks exactly on the 5th open, never twice, skips when the OS prompt is unavailable).
   Ships with the next version (already on `v3`).
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
8. **Eva — a daily "life lesson" everyone follows** *(engagement)* — **✅ SHIPPED as a
   story on `v3`** (2026-06-17→18): the "Your circle" strip on Trends now leads with a
   **You** story (tap → your shared meals, with a "scan a meal to start your story" nudge)
   and an **Eva** story avatar (tap → today's lesson in a story-style sheet, with the
   **author** under it). One lesson per **local date** (same for everyone, flips at local
   midnight) from a bundled set of **100 bilingual (EN/中文) lessons**, each now carrying a
   bilingual **attribution** (`byEn`/`byZh` — a real author where documented, else
   "Proverb"/"Unknown") — [`assets/eva_wisdom.json`](assets/eva_wisdom.json) via
   [`eva_wisdom.dart`](lib/src/data/eva_wisdom.dart) (`evaWisdomProvider` + pure
   `evaLessonIndex` + `author(lang)`), rendered in
   [`circle_strip.dart`](lib/src/features/circle/circle_strip.dart). The old pinned
   `eva_lesson_card.dart` was removed. No runtime model call (offline). Unit tests cover
   the date→index logic, `author()`, and the 100-entry attributed asset. **✅ (d)** Eva is
   now the followed story avatar (tap → lesson). **Open follow-ups (deferred):**
   (a) **Eva as a real server account** in `CircleTable` (friend graph + feed posts) vs.
   the current client-side story.
   (b) **Server-updatable lessons** (e.g. `/config/wisdom`) so the list refreshes without
   an app release — currently bundled.
   (c) **Daily local notification** ("Eva's lesson for today …") gated by the existing
   *Circle activity* toggle — not built yet.

   *(Original spec below.)* A built-in
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

9. **Make the micro Bean pack a REAL production IAP (not debug-only)** —
   **DECISION (2026-06): `beans_25` = 25 Beans @ S$0.48** (Apple's actual SGD floor — there's
   no 0.49 SGD point; a literal 1-Bean/S$0.02 can't be sold). **Client + server code landed
   on `v3`:** `beans_25` added to `BeanPricing.packs`
   ([`bean_transaction.dart`](lib/src/models/bean_transaction.dart)), `kBeanProductIds`
   ([`iap_service.dart`](lib/src/data/iap_service.dart)) and the server `PRODUCTS` map
   ([`backend/src/iap.py`](backend/src/iap.py)); unit + backend tests added (green). The
   **hidden 1-Bean debug freebie stays as-is** (separate, `kDebugMode`-only). **✅ ASC product
   created** — consumable `beans_25` (Apple ID 6780952980), S$0.48 base (US$0.29 / AUD$0.49
   comparable), EN ("25 Beans") + 简体中文 ("25 颗豆子") localizations, review screenshot,
   all-territory availability — status **Ready to Submit**. **Remaining:** (a) it rides the
   **next version (1.0.2)** — a new IAP must accompany a version submission, and 1.0.1 is
   still in review; (b) deploy the updated `iap.py` to prod when 1.0.2 ships. *(Below: the
   original blocker write-up.)*

   (Original note — today the **1-Bean / S$0.02** pack is a
   `kDebugMode`-only **free local credit**: it's hidden in `BeanPricing.hiddenPacks`
   ([`bean_transaction.dart`](lib/src/models/bean_transaction.dart)), revealed only by
   tapping the paywall title **10×** in a debug build (the `!kDebugMode` guard +
   `isHidden` local-credit bypass in
   [`beans_screen.dart`](lib/src/features/wallet/beans_screen.dart)), so it never
   reaches TestFlight/the App Store and takes no real money. Goal: a genuinely
   purchasable pack that works in production.
   - **⚠️ Hard blocker — Apple will not sell S$0.02.** In-app digital goods *must* go
     through IAP, and IAP has a **price floor** (Apple's lowest point is ≈ US$0.29; the
     SGD floor is ≈ **S$0.38–0.49** — confirm the exact tier in ASC). There is **no
     compliant way to charge S$0.02**. So the micro-pack **must be repriced to Apple's
     lowest tier** to become real, or it stays a non-purchasable dev shortcut.
     **Decision needed (you):** at the floor (~S$0.49) a single Bean is ~25× the
     per-Bean rate of the 100-pack (S$1.99 → ~S$0.02/Bean), so a real "1 Bean" pack is
     poor value — consider a **"smallest real pack"** (e.g. 25–50 Beans at the floor
     tier) instead of literally 1 Bean. Confirm price + size before building.
   - **ASC product** — create a new consumable (e.g. `beans_1` / `beans_25`) via the ASC
     API exactly like `beans_100…800` (§2): EN + 中文 localization, price at the chosen
     tier (Singapore base auto-converts), review screenshot, all-territory availability.
     First appearance of a new IAP **must ride a version submission**.
   - **Client** — move the pack out of `hiddenPacks` into `BeanPricing.packs`; add its id
     to `beanProductId`/`productBeans`
     ([`iap_service.dart`](lib/src/data/iap_service.dart)); and **delete the bypass** —
     the `isHidden` local-credit branch, the 10-tap reveal + `beansSecretUnlocked` string,
     and the `!kDebugMode` guard — so it buys through `IapService.buy` → `/iap/validate`
     like every other pack. **Keep the debug-only FREE credit separate** (it can stay,
     gated to `kDebugMode`); a paid product must never hit the free local path.
   - **Server** — no contract change: `/iap/validate` already credits any consumable,
     idempotent by Apple txn id (§2 Phase 3); just map the new product id → its Bean
     grant. Additive only — apply the `production-safety` skill.
   - **Tests** — extend the fake-store integration test + `BeanPricing`/`beanProductId`
     unit coverage for the new id.

## 📱 Device-only QA (QA_REPORT §5)

Sign in with Apple · Apple Health · local notifications · camera capture · weather
GPS · the signed-in Circle invites/feed — can't be automated on the simulator.
