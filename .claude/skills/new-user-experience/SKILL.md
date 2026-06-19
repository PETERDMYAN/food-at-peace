# Check the new-user experience (Food at Peace)

After **every user-facing feature change**, stop and look at the app the way a
**brand-new user who just onboarded** would — *before* you call it done. Most
bugs we ship aren't in the happy path with rich data; they're in the **cold,
empty, no-permission, signed-in-five-minutes-ago** state. Run this lens every
time, alongside the `ship-feature` before/after pictures.

## The new-user reality

A fresh user has, by default:
- **No data** — no meals logged, no Circle friends, no posts, no history (only
  the 100-Bean welcome grant). Stories/feeds/trends are empty.
- **No permissions** — Health, **notifications**, camera, photos, location are
  all **ungranted** until explicitly asked. A toggle defaulting "on" does
  **nothing** until the OS permission is actually granted.
- **Just signed in (or not at all)** — Circle/sync/Beans-ledger need an account;
  the feature must degrade gracefully when signed out.
- **System locale** (EN or 中文) and **default settings**.
- **First run of every flow** — onboarding, first scan, first post, first paywall.

## Checklist — run for each user-facing change

- [ ] **Empty state.** With zero data, does the new screen/section show a
      sensible, friendly empty state — not a blank box, a crash, a spinner that
      never resolves, or copy that assumes content exists? (e.g. "Top up Beans"
      vs "You're out of Beans" when they still have the grant.)
- [ ] **Permission CTA.** If the feature depends on a permission, is there a
      **clear, strong call-to-action to grant it**? Never default a toggle "on"
      and rely on a permission that was never requested — that's a silent no-op
      (this is exactly why the circle-notify CTA exists). Request at a moment
      that makes sense, and handle "denied" (point to Settings).
- [ ] **Sensible defaults.** Are defaults right for someone with **no history**?
      Don't assume prior meals, friends, weight trend, or saved preferences.
- [ ] **Signed-out / no-proxy.** Does it degrade gracefully with no account and
      no backend (no error spew, no dead buttons)? Circle/sync/posts/Beans-server
      are all no-ops when signed out.
- [ ] **No fabricated data.** Don't seed fake friends/posts/stats to fill the
      void (see the `no-dummy-data` skill). Eva/Roro are the only first-party
      exceptions, and they're real product entities.
- [ ] **Discoverability.** Can a new user actually *find* and *understand* the
      feature without prior context? Is the entry point visible from a cold start?
- [ ] **First-run flow intact.** If onboarding or a first-time flow is involved,
      walk it end-to-end — a new step, gate, or permission shouldn't strand them.
- [ ] **Both languages.** The empty/first-run copy reads correctly in EN **and**
      中文.

## How to actually look (don't just reason about it)

Pick the cheapest faithful check:
- **Fresh simulator state** — wipe and re-run: `xcrun simctl uninstall booted
  com.foodatpeace.foodAtPeace` (or **Erase All Content**), then launch. Empty
  prefs = a true new user.
- **Screenshot harness with empty overrides** — render the screen with
  `SharedPreferences.setMockInitialValues({})` and the data providers empty /
  signed out (mirror the seeding in `integration_test/` but *omit* the seed).
- **The dev TestFlight app** (`com.foodatpeace.foodAtPeace.dev`, v2 backend) —
  install and sign in with a spare Apple ID for a genuinely clean account.

## When to apply

- After implementing any user-facing change, **before** the `ship-feature`
  before/after step — and call out in your summary what the new-user path looks
  like (empty state + permission CTA especially).
- If the new-user path is broken or confusing, fix it as part of the same change,
  not "later."
