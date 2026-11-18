---
name: saw-work
description: "[4. Work] Implement a task cleanly with minimal human-reviewable diffs, verification tests, and post-work Goldfish diff review."
argument-hint: "[pack] <spec path or task/bug description>"
disable-model-invocation: true
---
# SAW Work

Read `.saw/protocol.md` first and follow P0–P5 (`phase = work`).

## 1. Fast-Path Check
If the task is clearly trivial (typo, comment, one-line config tweak), make the minimal change, run relevant checks from `.saw/profile.md`, and stop without spawning Goldfish.

## 2. Optional Blind Diagnosis (Ambiguous Bugs Only)
If fixing a non-obvious bug or hitting a puzzling failure:
1. Reproduce the failure first (prefer a failing test when practical).
2. Before anchoring on a guess, form your own hypothesis privately, then run active/on-demand `diagnostician` Goldfish passing ONLY `SYMPTOM` + `REPRO` + logs (never your hunch).
3. Compare evidence and pick the better-supported root cause.

## 3. Implement (Human-Reviewable Minimal Diff)
Follow the spec/task cleanly:
- **Minimal, focused diff**: Do not touch unrelated files, reformat surrounding lines, reorder unrelated imports, or perform drive-by refactors.
- **Readable over compressed**: Never cram logic into weird one-liners just to shrink line count; match repo idioms so a human reviewer can read the diff effortlessly.
- Add or update focused tests matching the spec's Verification Criteria.

## 4. Verification Loop
Run commands from `## Verification commands` in `.saw/profile.md` (and any task-specific tests).
- If failures occur, fix and re-run up to `rounds.work_fix` (default `3`).
- If still failing after `work_fix` attempts, stop and report exact failures and attempted fixes.

## 5. Post-Work Diff Review
Package pending changes into `<work>/review-round<N>.diff` (P4) and run active `review` lenses (`critic` + `simplifier`) up to `rounds.review_post` (default `2`):
- Fix real bugs, missing test assertions, or noisy/unreadable diff churn; note 1-line reasons for skipped items.
- Re-run verification commands after any final edit.
- In manual `/saw-work` mode, if `review_post` ends with open suggestions, ask whether to do one more round or wrap up.

## 6. Clean Up & Report
Delete throwaway `.diff` / `baseline/` snapshots; summarize files changed, verification command outputs, and any skipped review notes, then end with `Next: /saw-sync` (re-checks profile and listed docs against the new code). If this work created, moved, or deleted a doc file, append those paths (old and new for moves): `Next: /saw-sync <doc paths>`.
