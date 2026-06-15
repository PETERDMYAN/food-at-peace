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
- **TestFlight** — `1.0.1 (7)` built + uploaded headlessly via the ASC API key
  (see [`PUBLISHING.md`](PUBLISHING.md) §4). Adds the Associated Domains entitlement
  + `foodatpeace://` URL scheme; signing auto-provisioned the new capability.

Verified: Flutter 108 + backend 74 tests, `flutter analyze` clean. The full signed-in
Circle flow was exercised **in-app on two simulators** against the live v2 backend
(injected session tokens, since Apple sign-in can't run on a sim): user A scans +
posts a meal → user B opens A's invite → one-tap mutual connect → B's feed shows A's
photo → B reacts ❤️ → A receives it (all confirmed server-side too). Driver:
[`integration_test/circle_two_user_demo.dart`](integration_test/circle_two_user_demo.dart).

## 🚧 Remaining

1. **Host the invite-link AASA** *(you — universal link only)* — the in-app handler,
   entitlement, and custom-scheme fallback all ship in build 4. For the **universal
   link** to open the app from WeChat/WhatsApp you must own `foodatpeace.app` and
   host [`store/apple-app-site-association`](store/apple-app-site-association) at
   `/.well-known/`. Steps in [`store/INVITE_LINKS.md`](store/INVITE_LINKS.md).
2. **Beans IAP** — purchases/subscription are **dev stubs** (credit locally; a
   reinstall resets the balance). Needs `in_app_purchase` StoreKit + a backend
   `/iap/validate` endpoint (Apple receipt validation) + **App Store Connect IAP
   product creation + sandbox testing** (manual, external). Emit `purchase`/`refund`
   analytics once live.
3. **APNs push for circle notifications** — friend-meal alerts are currently
   surfaced locally (on app launch/resume vs a last-seen marker). For *instant*
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

## 📱 Device-only QA (QA_REPORT §5)

Sign in with Apple · Apple Health · local notifications · camera capture · weather
GPS · the signed-in Circle invites/feed — can't be automated on the simulator.
