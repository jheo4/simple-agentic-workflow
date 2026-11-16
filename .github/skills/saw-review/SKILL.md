---
name: saw-review
description: "[3. Review] Run an independent Goldfish review (critic + simplifier) on a task spec or pending code diff and apply pragmatic improvements."
argument-hint: "[pack] [spec path | 'diff' | focus]"
disable-model-invocation: true
---
# SAW Review

Read `.saw/protocol.md` first and follow P0–P4 (`phase = review`).

## 1. Determine Target
- If a spec/doc path (or active `.saw/work/*/spec.md`) is given: `TARGET_TYPE = pre-work` (reviewing spec/plan before coding).
- Otherwise (or if `diff` / no doc is passed): `TARGET_TYPE = post-work` — package pending git changes (or `<work>/baseline/` diff) per P4 into `<work>/review-round<N>.diff`.
- If the diff is trivial (typos, comments, single-line config), say so and skip Goldfish unless the user insists.

## 2. Run Active `review` Lenses
Run all `active` `review` lenses from the resolved pack (default: `critic` + `simplifier`) in parallel.
Pass ONLY `LENS` + `PROFILE` + `TARGET_TYPE` + target spec or diff path (+ optional user `FOCUS`).

## 3. Pragmatic Fix Loop (Manual Mode)
For each round up to `rounds.review_manual` (default `2`):
- If both return `SAW-STATUS: OK`, finish cleanly.
- Otherwise:
  - Fix concrete bugs, gaps, missing tests, or diff-hygiene issues directly in the spec/code.
  - For suggestions intentionally skipped, record a 1-line factual reason.
  - If code changed, re-run relevant verification commands from `.saw/profile.md`.
- If `rounds.review_manual` ends with remaining unapplied suggestions, summarize them concisely and ask the user: **"Run one more review round, or wrap up here?"**
- When wrapping up cleanly, end with `Next: /saw-work <spec-path>` (after `pre-work`) or `Next: /saw-sync` (after `post-work`).
