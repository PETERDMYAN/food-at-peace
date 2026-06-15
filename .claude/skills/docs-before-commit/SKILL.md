---
name: docs-before-commit
description: >
  Apply BEFORE every `git commit` / `git push` in this repo. Update TODO.md and
  readme.md so they always reflect the change being committed — mark finished
  items done, add new follow-ups, and refresh the readme status/build line — and
  stage them in the SAME commit. Triggers: about to run git commit or git push,
  finishing a feature/fix, shipping a TestFlight build, or anything that changes
  what's done vs. remaining.
---

# Keep TODO.md + readme.md in sync on every commit

The repo's living docs must never go stale. **Before you `git commit` (and push),
update both — in the same commit as the change:**

## 1. `TODO.md` — the source of truth for done vs. remaining
- Mark anything this change completes as **✅** / move it into "✅ Shipped on v2".
- Add any **new follow-up** the change introduces, with `file:line` / command pointers.
- When you ship a TestFlight build, **bump the build/version reference**.

## 2. `readme.md` — product tour + the `> **Status:**` block
- Refresh the status line: **current TestFlight build number**, what's **live**, and
  what's **remaining before the v2 release**.
- Add/adjust any feature description the change affects.

## How to apply
- Do it **as part of the same commit** as the change — not a follow-up commit — so
  history shows code + docs together (`git add TODO.md readme.md <code…>`).
- Keep edits tight and accurate; match the existing doc style (cite `file:line` /
  commands where useful).
- **Skip only** for a pure-docs edit or a trivial comment/typo fix that changes nothing
  about status or scope — and when you skip, **say so explicitly** rather than silently
  forgetting.

## Pre-commit checklist
- [ ] Did this **finish** a TODO item? → mark it done in `TODO.md`.
- [ ] Did this **add** new work? → add a `TODO.md` bullet.
- [ ] Did **status / build number / what's-live** change? → update `readme.md`.
- [ ] Are `TODO.md` / `readme.md` **staged in this same commit**?
