# Food at Peace — backend (AWS SAM)

An AWS SAM stack of Lambdas behind one HTTP API. It began as a vision proxy that
holds the Anthropic API key **server-side** (so no key ships in the app) and has
grown to also cover accounts/sync, account deletion, owner analytics, and the
**Circle** social layer (friend graph + a photo feed).

Endpoints (all on the one HTTP API):
- `POST /analyze` — food photo → structured nutrition estimate (Claude). `x-app-token`.
  Accepts an optional `lang` (`en`/`zh`) so the estimate comes back in the app's language.
- `POST /auth/apple` — Sign in with Apple → app session token.
- `POST /sync` · `POST /account/delete` — authenticated delta sync + account deletion (Bearer).
- `POST /event` · `GET /metrics` — owner-analytics counters (`x-app-token`).
- `POST /circle/register|invite|connect|respond|remove` · `GET /circle/list` — friend graph (Bearer).
  `connect` is one-tap mutual connect from an invite link/QR (both sides connected at once).
- `POST /circle/post|react` · `GET /circle/feed` — 3-day photo feed + emoji reactions (Bearer).

Tables: `SyncTable`, `MetricsTable`, `CircleTable`, `PostsTable` (the last with a
3-day DynamoDB TTL). Circle photos live in an S3 bucket with a 3-day lifecycle.
Handlers are pure stdlib + `boto3`, except `auth.py` (PyJWT[crypto], bundled by `sam build`).

```
App ──POST /analyze {image, mediaType} + x-app-token──▶ API Gateway (HTTP API, CORS)
                                                              │
                                                              ▼
                                                       Lambda (app.handler)
                                          reads the Claude key + app token from SSM
                                                              │
                                                              ▼
                                                  Anthropic Messages API
App ◀──── flat FoodAnalysis JSON (name, calories, proteinG, satFatG, …) ◀──┘
```

The handler ([src/app.py](src/app.py)) is pure standard library + `boto3` (both already
in the Lambda runtime), so there is nothing to bundle.

## Prerequisites

- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
  and AWS credentials configured (`aws configure`).
- An Anthropic API key.
- Python 3.13 (for `pytest`; matches the Lambda runtime).

## 1. Store the secrets in SSM (once)

These never go in the template or git. Pick any long random string for the app token
(e.g. `openssl rand -hex 24`).

```bash
aws ssm put-parameter --name /food-at-peace/anthropic-api-key \
  --type SecureString --value 'sk-ant-...'

aws ssm put-parameter --name /food-at-peace/app-token \
  --type SecureString --value "$(openssl rand -hex 24)"

# Session-token signing key (for Sign in with Apple — see "Accounts & sync").
aws ssm put-parameter --name /food-at-peace/session-signing-key \
  --type SecureString --value "$(openssl rand -hex 32)"
```

To rotate either later, re-run with `--overwrite`. The Lambda picks up the new value on
its next cold start (or redeploy to force it).

## 2. Deploy

> ⚠️ **Two isolated stacks share these secrets.** Production (1.0.x) is
> `food-at-peace-vision-proxy` (API `6m19l2b025`) — **never redeploy it for dev work.**
> The `v2` branch runs on `food-at-peace-vision-proxy-v2` (API `p21hoawoi5`).
> `samconfig.toml`'s default targets the **prod** name, so pass the v2 name explicitly.

```bash
sam build

# v2 (current dev stack):
sam deploy --stack-name food-at-peace-vision-proxy-v2 \
  --region ap-southeast-1 --capabilities CAPABILITY_IAM --resolve-s3 \
  --no-confirm-changeset --parameter-overrides AppleClientId=com.foodatpeace.foodAtPeace

# Production (only when intentionally shipping to the live app):
sam deploy --guided     # first time; afterwards just `sam deploy`
```

`--guided` writes your answers to [samconfig.toml](samconfig.toml). The default region is
`ap-southeast-1` (Singapore) — change it there if needed. On success SAM prints:

- **ProxyBaseUrl** — pass to the app as `PROXY_BASE_URL` (the app POSTs to `<base>/analyze`).
- **AnalyzeUrl** — the full endpoint, handy for curl.

## 3. Point the app at it

In `dart_defines.json` at the repo root (git-ignored):

```json
{
  "PROXY_BASE_URL": "https://abc123.execute-api.ap-southeast-1.amazonaws.com",
  "PROXY_APP_TOKEN": "the-same-app-token-you-put-in-ssm"
}
```

Then `flutter run --dart-define-from-file=dart_defines.json`. With no key in Settings the
app uses this proxy; a user who pastes their own Anthropic key still calls Anthropic
directly.

## Tests

```bash
pytest backend/tests/        # token rejection, body builder, parser, mocked happy path
```

No AWS calls or network access — secrets are stubbed and the Anthropic call is mocked.

## Local invoke (optional, needs Docker)

```bash
# Fill in events/event.json with a real base64 JPEG + your app token first.
sam build && sam local invoke VisionFunction -e events/event.json
```

This makes a *real* Anthropic call, so it needs the SSM secrets and AWS credentials.

## Cost guardrails

- HTTP API stage throttling (`ThrottlingRateLimit: 2`, `ThrottlingBurstLimit: 5`) caps
  the request rate, and your account's Lambda concurrency limit caps parallelism — a
  flood can't fan out into large Anthropic spend.
- The `x-app-token` check rejects unauthenticated callers before any Anthropic call.

> New AWS accounts start with a Lambda concurrency limit of ~10, so the template omits a
> per-function `ReservedConcurrentExecutions` cap (reserving any would drop unreserved
> capacity below AWS's minimum and fail the deploy). Add one once your account limit is
> raised, if you want a hard per-function cap.

> The app token gates the **photo proxy** — it ships in the app (like the old key did)
> but is revocable + scoped, and the guardrails bound the damage. **Per-user auth now
> exists for sync** via Sign in with Apple (see "Accounts & sync"); Google is a planned
> fast-follow.

## Accounts & sync (Sign in with Apple)

Two routes share this stack so a signed-in user's data follows them across devices:

- `POST /auth/apple` — the app sends the Apple **identity token** (+ a nonce).
  `AuthFunction` verifies it against Apple's public keys (JWKS, RS256; audience = the
  app **bundle id**, set via the `AppleClientId` parameter), then mints an HS256
  **session token** signed with `/food-at-peace/session-signing-key`. No Apple private
  key is needed for the native iOS flow.
- `POST /sync` — `Authorization: Bearer <sessionToken>`. Bidirectional delta sync of
  food / weight / profile into `SyncTable` (PK `userId`, SK `recordType#id`),
  last-write-wins by `updatedAt`, tombstone-aware for deletions.

Deploy needs the signing key (step 1 above) and your bundle id:

```bash
sam deploy --parameter-overrides AppleClientId=com.yourcompany.foodatpeace
```

> **`sam build` now installs dependencies.** `src/requirements.txt` lists `PyJWT[crypto]`
> for token verification, so the build bundles it — it's no longer a no-op.

## Notes

- **Model** is chosen server-side via the `MODEL` env var (default `claude-sonnet-4-6`)
  — swap models without an app update.
- **CORS** is configured on the HTTP API (`content-type`, `x-app-token`; `POST`/`OPTIONS`),
  so the Flutter **web** build (`flutter run -d chrome`) can call the proxy too.
- **DynamoDB sync is implemented** — `SyncTable` + the `/sync` route share this stack
  (see "Accounts & sync" above).
