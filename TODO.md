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
  - Remove a friend from the trend sheet.
  - **Photo feed ("stories")** — share a scanned meal (toggle, default on) to your
    circle; friends react with emojis; you receive the reactions; posts auto-expire
    after **3 days**. ([`backend/src/posts.py`](backend/src/posts.py), `PostsTable` +
    an S3 photos bucket; [`posts_client.dart`](lib/src/data/posts_client.dart),
    [`circle_feed_screen.dart`](lib/src/features/circle/circle_feed_screen.dart)).
    The **story keeps the full-resolution photo**; the AI estimate uses a downscaled
    1024px copy.
- **TestFlight** — `1.0.1 (2)` built + uploaded headlessly via the ASC API key
  (see [`PUBLISHING.md`](PUBLISHING.md) §4).

Verified: Flutter 93 + backend 68 tests, `flutter analyze` clean. The signed-in
Circle paths (invites + feed) need a real device (Apple ID) to exercise end-to-end
— verified server-side with live two-user runs.

## 🚧 Remaining

1. **Invite deep-link** — `https://foodatpeace.app/i/<handle>` (and/or a
   `foodatpeace://` custom scheme) opens the app with the invite pre-filled. Needs
   the Associated Domains entitlement + a hosted `apple-app-site-association` (or
   just the custom scheme to start) and an in-app link handler.
2. **Beans IAP** — purchases/subscription are **dev stubs** (credit locally; a
   reinstall resets the balance). Needs `in_app_purchase` StoreKit + a backend
   `/iap/validate` endpoint (Apple receipt validation) + **App Store Connect IAP
   product creation + sandbox testing** (manual, external). Emit `purchase`/`refund`
   analytics once live.

## 📱 Device-only QA (QA_REPORT §5)

Sign in with Apple · Apple Health · local notifications · camera capture · weather
GPS · the signed-in Circle invites/feed — can't be automated on the simulator.
