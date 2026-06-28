# Google Sign‑In — design & build plan

> **Status:** ✅ Design approved (decisions below). ⛔ **Blocked on one prerequisite you
> own:** a **Google Cloud OAuth client** (Part A) — I can't create that (account/console +
> consent screen). Everything in Part B is ready to build the moment you hand over the client
> IDs. Additive only; the shipped 1.0.0+ contract stays intact, dev on **v2** first.

## Decisions (yours, 2026‑06‑27)
1. **Bind conflict → Refuse + explain.** Linking is allowed only when the Google login is
   *unused*; if it already has its own account+data, we block with a clear message (no merge,
   no data loss).
2. **Both directions.** Apple‑first users can add Google **and** Google‑first users can add
   Apple. → the shipped `/auth/apple` gains a backward‑compatible alias lookup.
3. **iOS app + web `/recharge`.** Google appears in the app *and* on the web top‑up page
   (needs a separate Google **web** OAuth client).

## Why an identity‑alias layer (the key constraint)
There is **no account record** today: `user_id = "apple:" + sub` is used **directly** as the
data key for Sync, Beans, and — critically — **Circle** (`@handle`, friend edges, profile
photo all key off `user_id`). So an existing account's id **must never change**, or the friend
graph breaks. Google therefore can't *replace* an id — it must **alias** to it.

Add one tiny table; the canonical id stays whatever it already was. The session token is
unchanged (`sub` = canonical id), so Sync/Circle/Beans need **zero** changes.

```
IdentityTable (new, additive, PAY_PER_REQUEST)
  forward  pk = "idp#<provider>:<sub>"                 → { canonicalUserId }   # resolve a login
  reverse  pk = "user#<canonicalUserId>", sk="idp#…"   → { provider, linkedAt, email }  # list/unlink
```
- Canonical id = the account's **original** id: `apple:X` for today's users, `google:Y` for a
  brand‑new Google user. **Never rewritten.**
- A self‑alias row is written for the canonical identity too, so resolution is uniform.

## Flows
**A — new user, Google**
```
App: Google Sign-In → Google ID token
 → POST /auth/google { idToken }
     verify (RS256 vs Google JWKS https://www.googleapis.com/oauth2/v3/certs,
             iss ∈ {accounts.google.com, https://accounts.google.com},
             aud ∈ GOOGLE_CLIENT_IDS, exp)               # same jwtlite RS256 as Apple
     resolve idp#google:<sub>
       miss → canonical = google:<sub>; write alias rows; mint token   (fresh account)
       hit  → mint token for mapped canonical id                       (returning/bound)
```
**B — existing user binds Google** (signed in, canonical = apple:X)
```
Settings → Account → "Link Google account"
 → POST /auth/link/google { idToken }  (Authorization: Bearer <current session>)
     verify Google token → google sub
       already linked to THIS account → no-op
       google sub already maps elsewhere / has data → 409 CONFLICT (refuse + explain)
       else → write alias idp#google:<sub> → apple:X
 → henceforth /auth/google for that person resolves to apple:X (same data, @handle, friends)
```
**B′ — existing Google‑first user binds Apple** (symmetric; this is why both endpoints resolve aliases)
```
POST /auth/link/apple { identityToken, rawNonce }  (Bearer <current session>)
  → write alias idp#apple:<sub> → google:Y
/auth/apple then resolves idp#apple:<sub> → google:Y   (no alias row → apple:<sub>, i.e. today's behavior)
```

## Backend changes (all additive; **v2 → prod with the 1.0.3 cutover**)
- New **`IdentityTable`** in `template.yaml`.
- New **`auth_google.py`**: `/auth/google` (sign in/up) + `/auth/link/google` (bind, Bearer‑gated),
  reusing `jwtlite.verify_rs256` + a small `GoogleVerifier` (JWKS cache like `auth.py`).
- **`auth.py`**: add alias resolution to `/auth/apple` (resolve `idp#apple:<sub>`; **no row →
  `apple:<sub>`**, identical to today → backward‑compatible) + new `/auth/link/apple`.
- A shared **`identity.py`** helper: `resolve(provider, sub) → canonicalUserId`, `link(...)`,
  `conflict?` checks (does this sub already map, or already own Sync rows?).
- **`account.py`**: on delete, also remove the user's alias rows (forward + reverse) so a deleted
  account can't be resurrected via its Google login.
- **`recharge.py`** (web): accept a Google ID token path for web sign‑in, mirroring its existing
  Apple‑web path, into the same account.
- SSM: **`GOOGLE_CLIENT_IDS`** (comma‑separated: iOS client id + web client id), like
  `APPLE_CLIENT_ID`. Verification accepts any listed audience.
- Tests (`backend/tests/`): new‑user create, returning resolve, bind happy‑path, **bind‑conflict
  refusal**, both‑direction binding, deletion clears aliases. Google JWKS mocked (no network).

## Client changes (iOS‑first; Android later needs only its own client id)
- Add **`google_sign_in`** package; iOS config (Google OAuth **iOS** client id + reversed‑client‑id
  URL scheme in `Info.plist`).
- `auth_client.dart`: `signInWithGoogle()` → `/auth/google`; `linkGoogle()` / `linkApple()` →
  `/auth/link/*`. `authProvider` notifier methods to match.
- UI: **"Continue with Google"** under "Sign in with Apple" in
  [`onboarding_screen.dart`](lib/src/features/onboarding/onboarding_screen.dart) +
  [`settings_screen.dart`](lib/src/features/settings/settings_screen.dart); a **"Link Google
  account"** row in Settings → Account when signed in (→ "Linked ✓", with unlink). EN + 中文.

## Web changes (`store/website/recharge/`)
- Add **"Continue with Google"** via Google Identity Services (GIS) → ID token → existing
  `/auth/*` path. Needs the Google **web** OAuth client (authorized origin
  `https://foodatpeace.app`).

## Security
- Link **only** by explicit signed‑in action or provider `sub` — **never auto‑merge by email**
  (email isn't a safe join key). Google token fully verified server‑side (sig/iss/aud/exp), like
  Apple. Refuse‑on‑conflict means a link never silently moves or merges existing data.

---

## Part A — what *you* do (the prerequisite, start now)
Create a **Google Cloud OAuth client** (I can't — it needs your Google account + accepting
Google's terms + the OAuth consent screen):
1. Google Cloud Console → create/select a project (e.g. "Food at Peace").
2. **APIs & Services → OAuth consent screen** → External; app name, support email, your domain
   `foodatpeace.app`; add yourself as a test user.
3. **Credentials → Create credentials → OAuth client ID → iOS** → bundle id
   `com.foodatpeace.foodAtPeace` → copy the **iOS client id** (+ its reversed‑client‑id).
4. **Create credentials → OAuth client ID → Web application** → authorized JavaScript origin
   `https://foodatpeace.app` → copy the **Web client id** (+ secret, for the web path).
5. (Android later) a separate Android client id when we ship Android.
6. **Hand me:** the **iOS client id**, the **Web client id** (+ secret), and the **reversed iOS
   client id**.

> 🔎 I can co‑drive the console with you over the Chrome tool and annotate the exact screens
> once you're in (it's behind your Google login, so I can't screenshot it until then) — same as
> we'll do for any setup.

## Part B — what *I* build (the day you finish Part A)
1. Backend on **v2**: `IdentityTable`, `auth_google.py`, `identity.py`, `/auth/apple` alias
   lookup, `/auth/link/*`, `account.py` alias cleanup, tests. Changeset‑previewed, additive.
2. App: `google_sign_in`, the two buttons + the link row, strings, simulator verification.
3. Web: GIS button on `/recharge`.
4. Verify on v2 end‑to‑end (new Google user, Apple→Google bind, Google→Apple bind, conflict
   refusal, account‑delete clears aliases), then roll into the **1.0.3** prod cutover.

*Created 2026‑06‑27. Pending your Google Cloud OAuth client (Part A).*
