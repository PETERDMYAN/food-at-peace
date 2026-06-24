# Garmin direct integration — step guide & build plan

> **Status:** ⛔ **Blocked on access (Part A).** Garmin's consumer data is behind a
> **gated partner program** — not self-serve. Nothing on the engineering side can start until
> *you* apply and Garmin approves you (Part A). Everything in Part B is ready to build the day
> you hand over credentials. Tracked in [`TODO.md`](TODO.md).

## Why we want this

Today Garmin reaches the app **only indirectly**: a Garmin watch syncs to Apple Health, and the
app reads active energy from **HealthKit**. That path breaks down when:

- the user is on **Android / no HealthKit**, or
- the user hasn't routed **Garmin → Apple Health**, or
- we want **Garmin-specific** data (all-day active calories, activities) as a first-class,
  selectable source in the **Data Sources** screen.

This adds a **first-class Garmin path**: the user OAuth-connects their Garmin account, we pull
their **active energy** directly, and feed it into the **same `energyOut`** the targets engine
already consumes — so no nutrition math changes, Garmin just becomes another provider of
"measured active energy."

---

## Part A — what *you* do (get access) ⏳ this is the long pole, start now

1. **Open the Garmin developer portal** → the **Garmin Connect Developer Program → Health API**
   (developer.garmin.com → "Health API" / "Wellness API").
2. **Request access / apply.** The form asks you to describe: the app (*Food at Peace — a
   calorie & macro tracker*), the **data you need** (**daily summaries → active calories**;
   optionally **activities** for workouts), the developer/company entity, and your **data-use /
   privacy** intent (we only read the connected user's own energy data, to compute their
   calorie budget).
3. **Wait for Garmin's review.** It's a **manual approval** and can take days–weeks. This blocks
   everything else, so submit it first.
4. **After approval, create an app** in the portal and copy the **Consumer Key** + **Consumer
   Secret** (the OAuth credentials).
5. **Set the callback / redirect URL** to one I'll give you on our domain (e.g.
   `https://foodatpeace.app/garmin/callback`, backed by API Gateway).
6. **Enable the summary types** you want — at minimum **Daily summaries** (that's where
   `activeKilocalories` lives); **Activities** too if we want workouts. If Garmin uses their
   **push/ping** delivery, register the **webhook URL** I'll provide.
7. **Hand me three things:** ① the **Consumer Key + Secret**, ② the **OAuth flavour** the portal
   shows you (Garmin migrated the Health API to **OAuth 2.0 + PKCE**; older docs/apps use **OAuth
   1.0a** — tell me which yours is), ③ the **list of enabled summary types**.

> 🔎 **I can do this part *with* you.** The portal sits behind Garmin's login, so I can't
> screenshot it until we're in — but once you're approved, I'll drive the portal with you over
> the Chrome tool and annotate the exact screens. The labels above are from Garmin's public docs.

**⚠️ I cannot do Part A for you:** it requires creating a Garmin developer account and accepting
their partner terms — account creation / accepting agreements are yours to do, and the approval
is Garmin's to grant.

---

## Part B — what *I* build (the day you finish Part A)

**Backend** — new Lambdas in the SAM stack, **v2 first, then prod** (additive; the shipped
contract is untouched):

1. **`garmin_oauth.py`** — the connect flow:
   - `GET /garmin/start` → returns Garmin's **authorize URL** (with PKCE challenge / OAuth1
     request token, per your flavour).
   - `GET /garmin/callback` → exchanges the code/verifier for the user's **Garmin access
     token**, stored on their account. Gated by the **same Bearer session token** as `/sync`, so
     the Garmin link is bound to the signed-in Food-at-Peace account.
2. **`garmin_data.py`** — ingest active energy:
   - If Garmin **pushes** (their Ping/Push service POSTs summaries as they arrive): a signed
     `POST /garmin/push` handler verifies the signature, pulls **`activeKilocalories`** + the day
     out of each **daily summary**, and writes a per-day **Garmin active-energy** row.
   - **Backfill** on first connect via Garmin's pull endpoints (last N days).
3. **Storage + wiring** — a `GarminTable` (token + per-day energy) keyed by our user id; reuse
   `common.py` / `session.py` / the SSM-secret pattern; declare routes + table in
   [`backend/template.yaml`](backend/template.yaml). Tests under `backend/tests/` with Garmin
   **mocked** (no network), matching the existing style.

**App** (`lib/`, ships in a normal release — likely **1.0.4**):

4. A **`GarminService`** + provider mirroring [`health_service.dart`](lib/src/data/health_service.dart)'s
   abstract shape, and a **"Connect Garmin"** entry in the **Data Sources** screen alongside Apple
   Watch / iPhone — it opens the OAuth URL in a browser tab and returns to the app.
5. Feed Garmin active energy into the **same `energyOut`** the targets engine uses
   ([`nutrition/nutrition_math.dart`](lib/src/nutrition/nutrition_math.dart) + `DailySummary.compute`),
   respecting the existing **data-source priority** so Apple Health + Garmin **never double-count**
   — whichever source the user prioritises wins.

---

## Part C — data shape (how it slots in, why the math doesn't change)

- A Garmin **Daily Summary** carries **`activeKilocalories`** (kcal) per calendar day. That is
  the *same quantity* HealthKit gives us as "active energy."
- The targets engine already takes **measured active energy** as an input (calorie budget =
  full-day BMR + measured active energy + goal gap). Garmin simply becomes **another provider**
  of that one number — **no formula changes.**
- **Source priority:** the Data Sources screen already lets the user pick which device's active
  energy wins when several report. Garmin-direct becomes one more selectable source under the
  same priority logic, which is what prevents double-counting.

---

## Timeline

| When | Who | What |
|---|---|---|
| **Now → weeks** *(blocking)* | **You** | Apply to the Health API (Part A); Garmin reviews & approves. |
| **~1–2 days after credentials** | Me | Build + test Part B's backend on **v2**, then deploy to **prod** (additive). |
| **Next app release (~1.0.4)** | Me | Ship the Data Sources **"Connect Garmin"** UI + energy wiring. |

---

*Created 2026-06-24. The OAuth specifics (1.0a vs 2.0/PKCE) and the exact portal labels need
confirming against Garmin's current docs once you're inside the approved developer account — I'll
finalise them with you then.*
