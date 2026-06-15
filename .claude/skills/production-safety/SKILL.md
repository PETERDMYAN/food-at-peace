---
name: production-safety
description: >
  Read and apply BEFORE any change that could touch the LIVE production
  integration between the client and the server. Triggers: editing a backend/
  Lambda or template.yaml, running sam deploy, changing dart_defines.json /
  PROXY_BASE_URL, altering the request/response shapes in food_photo_analyzer,
  claude_vision_client, sync_client, or auth_client (or the models they
  serialize), touching the production stack (food-at-peace-vision-proxy /
  6m19l2b025), or pushing to main. Goal: never break the App Store 1.0.0 app.
---

# Production safety — never break the live client↔server integration

The App Store-approved **1.0.0** app is in production and bound to the
**production proxy** `food-at-peace-vision-proxy` (HTTP API `6m19l2b025`,
`ap-southeast-1`). Every installed copy depends on that exact contract and
**cannot be patched on demand**. Treat the shipped client↔server integration as
**immutable** — extend it, never break it.

## Hard rules

1. **Never redeploy or mutate the production stack for in-progress work.**
   Dev (v2 and beyond) uses the ISOLATED stack
   `food-at-peace-vision-proxy-v2` (API `p21hoawoi5`), which shares the same SSM
   secrets. `sam deploy` MUST pass `--stack-name food-at-peace-vision-proxy-v2`
   (`backend/samconfig.toml` defaults to the prod name). If a change *must* reach
   the prod stack, **stop and confirm with the user first**.

2. **Every shared endpoint stays backward-compatible.** `/analyze`,
   `/auth/apple`, `/sync`, `/account/delete` are consumed by the shipped 1.0.0
   app. New request fields must be **optional with the old behavior as the
   default** (e.g. `lang` absent → English). Never rename, remove, retype, or
   repurpose an existing request/response field; never change a status code's
   meaning, tighten validation, or change auth in a way an already-installed
   client can't handle. **Add, don't alter.**

3. **The contract is two-sided.** Before changing `food_photo_analyzer.dart`,
   `claude_vision_client.dart`, `sync_client.dart`, `auth_client.dart` (or the
   models they (de)serialize), check that the server still accepts/returns what
   the SHIPPED app sends/expects — and that the shipped server still satisfies
   the new client. Remember the Anthropic request is duplicated in
   `claude_vision_client.dart` (Dart) and `backend/src/app.py` (Python): change
   one → change the other.

4. **Don't cross the wires.** Only change `PROXY_BASE_URL` in `dart_defines.json`
   for the branch you're building, and never ship a production build pointing at
   the v2 stack (or vice-versa).

5. **Verify before declaring safe.** For any backend/contract change run
   `pytest backend/tests/`, `flutter analyze`, and `flutter test`; when it
   touches a live path, make a real call against the **v2** endpoint only —
   never production.

## Pre-commit checklist (backend or contract change)

- [ ] Any deploy targets the **v2** stack, not `6m19l2b025`.
- [ ] New fields are optional; no existing field renamed / removed / retyped.
- [ ] An old client that omits the new fields still works → behavior unchanged.
- [ ] Dart and Python stay in sync if the analyze request changed.
- [ ] `pytest` + `flutter analyze` + `flutter test` green; any live check hit v2.

If you cannot guarantee the shipped 1.0.0 app keeps working, **STOP and ask the
user** rather than risk the production integration.
