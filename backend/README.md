# Food at Peace — vision proxy (AWS Lambda)

A small Lambda + API Gateway proxy that holds the Anthropic API key **server-side**
so it never ships inside the app. The app POSTs a food photo; the proxy calls
Anthropic and returns the structured nutrition estimate.

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
```

To rotate either later, re-run with `--overwrite`. The Lambda picks up the new value on
its next cold start (or redeploy to force it).

## 2. Deploy

```bash
sam build
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

> The app token is a stopgap: it ships in the app (like the old key did) but is
> revocable and scoped, and the guardrails bound the damage. When real user login
> (Sign in with Apple / Google) lands, swap it for per-user auth.

## Notes

- **Model** is chosen server-side via the `MODEL` env var (default `claude-sonnet-4-6`)
  — swap models without an app update.
- **CORS** is configured on the HTTP API (`content-type`, `x-app-token`; `POST`/`OPTIONS`),
  so the Flutter **web** build (`flutter run -d chrome`) can call the proxy too.
- Adding **DynamoDB** daily-sync later: add the table + a second function/route to
  [template.yaml](template.yaml); it shares this stack.
