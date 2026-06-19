# Web Beans recharge (Stripe)

A standalone top-up page at **`https://foodatpeace.app/recharge`** that credits a
user's server-side **Beans** ledger via **Stripe Checkout** — no Apple cut, and a
top-up path for **Android / web** users who have no StoreKit. It reuses the same
`BeansTable` ledger as the in-app flow (`beans.py` / `iap.py`), so a balance topped
up on the web shows up in the app on next sync.

## Pieces

| Piece | Path |
|---|---|
| Lambda (checkout + webhook) | [`backend/src/recharge.py`](../backend/src/recharge.py) |
| Tests | [`backend/tests/test_recharge.py`](../backend/tests/test_recharge.py) |
| Web page (bilingual EN/中文) | [`store/website/recharge/index.html`](website/recharge/index.html) |
| Infra (routes, IAM, params) | [`backend/template.yaml`](../backend/template.yaml) |

## How it works

```
browser (foodatpeace.app/recharge)                 Stripe                 AWS
  │  POST /recharge/checkout  {productId}  ──────────────────────────────▶ recharge.py
  │      (Authorization: Bearer <sessionToken>)        create session ◀────┤
  │  ◀── { url } ───────────────────────────────────────────────────────  │
  │  window.location = url ─────────────▶ hosted card form
  │                                         pays ──┐
  │  ◀── redirect to /recharge?status=success ─────┘
  │                                                  checkout.session.completed
  │                                                  (signed webhook) ─────▶ POST /recharge/webhook
  │  poll GET /beans until credited  ◀──── credit BeansTable (idempotent) ──┤
```

**Fraud model (identical to `iap.py`).** Beans are credited **only** by the webhook,
**only** after Stripe's HMAC `Stripe-Signature` is verified, **idempotent** by Stripe
session id, and the Beans amount is **recomputed from `productId`** server-side (the
client-supplied `metadata.beans` is never trusted). A forged request can't mint Beans.
Stripe (hosted Checkout) holds all card data — none touches us. Stripe is hand-rolled
(urllib + `hmac`), so nothing is added to the shared `backend/src/requirements.txt`.

**Graceful when unconfigured.** With no Stripe secrets in SSM, `/recharge/checkout`
returns `{ "configured": false }` (200) and the page shows a friendly "card payments
aren't on yet" — exactly like `iap.py`'s `unconfigured` fallback. Nothing errors.

## ⚠️ App Store 3.1.1 — keep it standalone

Beans are a digital good consumed inside the iOS app, so Apple Guideline **3.1.1**
forbids the app from linking out to this page. **Do not add an in-app button to
`/recharge`** — in-app buying stays on StoreKit (`iap_service.dart`). This page is a
standalone web destination (for Android/web, support top-ups, the 中文 crowd). The
build adds **no app change**, so the App Store app is untouched.

## Identity — Sign in with Apple (web)

The page identifies the account with **Sign in with Apple, in the browser** (a "Sign in
with Apple" button on the gate; an *Advanced (testing)* disclosure still accepts a pasted
session token). It reuses the existing **`POST /auth/apple`** — the page sends Apple's web
`id_token`, the Lambda verifies it (RS256 / JWKS / audience / expiry, same as the native
app) and mints the session token. **Crucially, Apple returns the same `sub` for a person
whether they sign in via the native app or the web Services ID under the same team, so the
web login lands on the *same* Beans ledger** — a top-up on the web shows up in the app on
next sync. No new endpoint, and no app change.

This needs a **Services ID** (one-time, in the Apple Developer portal). The page expects
the identifier **`com.foodatpeace.web`** (constant `APPLE_SERVICES_ID` in
[`recharge/index.html`](website/recharge/index.html)); it's already in the v2 stack's
accepted-audience list (`APPLE_CLIENT_ID`).

1. **Certificates, IDs & Profiles → Identifiers → ＋ → Services IDs.** Description
   "Food at Peace Web", identifier **`com.foodatpeace.web`** (must match `APPLE_SERVICES_ID`;
   if you pick another, tell me — it's a one-line page change + a v2 redeploy).
2. Tick **Sign in with Apple → Configure**:
   - **Primary App ID:** `com.foodatpeace.foodAtPeace` (team `GJB4AB92L4`).
   - **Domains and Subdomains:** `foodatpeace.app`
   - **Return URLs:** `https://foodatpeace.app/recharge`
3. Apple shows a **domain-association file** to prove you own the domain. Download
   `apple-developer-domain-association.txt` and host it (send it to me, or run it yourself):
   ```bash
   aws s3 cp apple-developer-domain-association.txt \
     s3://foodatpeace-app-web/.well-known/apple-developer-domain-association.txt \
     --content-type text/plain
   aws cloudfront create-invalidation --distribution-id E2M22G0LAT1HKW \
     --paths '/.well-known/apple-developer-domain-association.txt'
   ```
   Then click **Verify** in the portal and **Save**. The Services ID is already trusted by
   the backend, so "Sign in with Apple" on the page works as soon as Apple verifies.

## Deploy + go-live (one-time)

> Dev/test runs against **v2** (`p21hoawoi5`). The page defaults to the v2 API. Prod
> (`6m19l2b025`) cutover is a separate, deliberate step — see the bottom.

1. **Create the Stripe secrets in SSM** (region `ap-southeast-1`). Use **test** keys
   first (`sk_test_…`). The webhook secret comes from step 3, so set a placeholder now:
   ```bash
   aws ssm put-parameter --region ap-southeast-1 --type SecureString \
     --name /food-at-peace/stripe-secret-key --value 'sk_test_xxx' --overwrite
   aws ssm put-parameter --region ap-southeast-1 --type SecureString \
     --name /food-at-peace/stripe-webhook-secret --value 'whsec_placeholder' --overwrite
   ```
2. **Deploy the v2 stack** (adds `RechargeFunction` + the two routes):
   ```bash
   cd backend && sam build && sam deploy --stack-name food-at-peace-vision-proxy-v2 \
     --region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3 \
     --no-confirm-changeset --parameter-overrides AppleClientId=com.foodatpeace.foodAtPeace
   ```
   Note the `RechargeWebhookUrl` output, e.g.
   `https://p21hoawoi5.execute-api.ap-southeast-1.amazonaws.com/recharge/webhook`.
3. **Register the webhook in the Stripe dashboard** → Developers → Webhooks → *Add
   endpoint*:
   - **Endpoint URL:** the `RechargeWebhookUrl` from step 2.
   - **Events to send:** `checkout.session.completed`.
   - Copy the endpoint's **Signing secret** (`whsec_…`) and store it for real:
     ```bash
     aws ssm put-parameter --region ap-southeast-1 --type SecureString \
       --name /food-at-peace/stripe-webhook-secret --value 'whsec_REAL' --overwrite
     ```
   (SSM is read per Lambda cold start — no redeploy needed to pick up new secret values.)
4. **Publish the page** to the live site (S3 + CloudFront). Upload it to **both** the
   `recharge/` folder **and** a "bare" `recharge` key — S3's index document only serves
   `/recharge/` (trailing slash); the bare object makes `/recharge` (no slash, the URL we
   advertise) resolve too. (The existing `/dashboard` uses this same two-object trick.)
   ```bash
   aws s3 sync store/website/recharge s3://foodatpeace-app-web/recharge \
     --content-type "text/html; charset=utf-8"                 # serves /recharge/
   aws s3 cp store/website/recharge/index.html s3://foodatpeace-app-web/recharge \
     --content-type "text/html; charset=utf-8"                 # serves /recharge  (no slash)
   aws cloudfront create-invalidation --distribution-id E2M22G0LAT1HKW \
     --paths '/recharge' '/recharge/' '/recharge/*'
   ```
   > ⚠️ The bare `recharge` object is **not** part of the `store/website/` tree (you can't
   > have a file and a folder of the same name locally), so a full-site
   > `aws s3 sync store/website … --delete` would delete it (and `dashboard`, `ttw`).
   > Re-run the `cp` above after any such sync, or just deploy additively as shown here.

## Test it end-to-end (test mode)

1. Open `https://foodatpeace.app/recharge` and tap **Sign in with Apple** (needs the
   Services ID + domain file from the section above). The balance + packs then load.
   *Token-only shortcut* (skips the Apple setup): mint/copy a session token (`/auth/apple`
   or a dev `.dev` install), then either open `…/recharge?t=<sessionToken>` or paste it under
   **Advanced (testing)** — the page stores it in `sessionStorage` and strips it from the URL.
2. Pick a pack → **Pay** → on Stripe's test form use card **`4242 4242 4242 4242`**, any
   future expiry, any CVC/postal.
3. You're redirected back to `…/recharge?status=success`; the page polls `/beans` and
   shows the new balance. Confirm the ledger row server-side:
   ```bash
   curl -s https://p21hoawoi5.execute-api.ap-southeast-1.amazonaws.com/beans \
     -H "authorization: Bearer <sessionToken>" | python3 -m json.tool
   ```

## Prod cutover (when you're ready for real users)

1. Put **live** Stripe keys (`sk_live_…`, and a webhook registered against the **prod**
   `…6m19l2b025…/recharge/webhook` → its own `whsec_…`) in the prod account's SSM.
2. Deploy `RechargeFunction` to **prod** with a previewed changeset (additive — it does
   not touch the 1.0.0 contract; follow the `production-safety` skill).
3. Flip `DEFAULT_BASE` in [`recharge/index.html`](website/recharge/index.html) from `V2`
   to `PROD`, re-sync the site, invalidate CloudFront.
