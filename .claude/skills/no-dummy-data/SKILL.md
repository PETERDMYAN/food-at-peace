# No dummy data in production

**Demo / sample / seeded / placeholder data must NEVER reach a real user.** It's
both an embarrassment and an App Store rejection risk (Guideline 2.1 — apps with
placeholder content are rejected). This burned us once: `CircleNotifier` seeded
fake friends (Mia/Jay/Sara/Ben) for signed-out users, so every new install showed
fabricated friends + a fake friend request.

## The rule
- The shipped app (`lib/`) must render an **honest empty state** for a brand-new
  user — never invented friends, posts, meals, balances, trends, or "example" rows.
- Demo content for **screenshots / videos / tests** lives ONLY in
  `integration_test/` + `test/` via **provider overrides** or
  `SharedPreferences.setMockInitialValues` — never as a fallback inside `lib/`.
- If a screen looks empty without seed data, that's a **design task** (write a real
  empty state / nudge), not a reason to seed fake data into the app.
- Intentional first-run content is allowed only when it's a *real product feature*
  the user understands as the app's own (e.g. Eva's built-in daily lesson, a Beans
  welcome grant) — never data masquerading as the user's own activity or other people.

## Smells to grep for in `lib/` before any release
`seed`, `sample`, `mock`, `dummy`, `demo`, `placeholder`, `fake`, hard-coded person
names, and any `?? <non-empty default>` / `_seededOrLocal`-style fallback that
returns content when the real source is empty.

```bash
grep -rnE "seed|sample|mock|dummy|demo|placeholder|fake|Eva|Peter|Mia" lib/ \
  | grep -viE "//|/\*|\*|l10n|placeholders\"|eva_wisdom|EvaLesson|evaWisdom"
```

## Verify before shipping / submitting
1. **Fresh install, signed OUT** → every list/feed/graph is empty or shows a real
   empty-state, with zero invented entities. (This is the default a reviewer sees.)
2. **Fresh install, signed IN** → same; data only appears once the user creates it
   or it legitimately syncs from their own account.
3. If a prior build seeded data, ship a **one-time migration** that strips it from
   existing users' local stores (don't just stop seeding — clean up what's cached).

## Pre-commit / pre-release check
- [ ] No seed/sample/mock fallback in `lib/` that a real user would see.
- [ ] Demo data is test-only (overrides / mock prefs), never in `lib/`.
- [ ] New-user empty states verified signed-out AND signed-in.
- [ ] Migration in place if an older build seeded data.
