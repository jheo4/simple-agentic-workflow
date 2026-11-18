---
name: saw-run
description: "[Auto] Full end-to-end auto workflow: draft spec -> single user confirmation -> non-stop pre-review, work, tests, post-review, and sync."
argument-hint: "[pack] <task or feature description>"
disable-model-invocation: true
---
# SAW Run (Full Auto)

Execute the complete task lifecycle end-to-end with **exactly one human checkpoint** right after Spec creation, then run all remaining phases pragmatically without stopping.

Read `.saw/protocol.md` first and follow P0–P5. Do not invoke other skills via a Skill tool—execute each phase directly using the same `.saw/protocol.md` and `.saw/packs/` rules.

## 0. Fast-Path Check
If the request is clearly trivial (typo, comment, single-line tweak), tell the user SAW is overkill here, apply the minimal fix directly, run checks, and finish.

## 1. Phase: Spec (Internal Clarity + Single User Checkpoint)
1. Inspect touched/related code and draft `.saw/work/<yyyy-mm-dd>-<slug>/spec.md` (goal, in/out scope, likely files, edge cases, verification criteria).
2. Run active `spec` lenses (`clarity`) up to `rounds.spec` (default `1`) and silently tighten `spec.md` before presenting it.
3. **CHECKPOINT (Ask User Once)**:
   Show the concise spec + verification plan and ask:
   > **"Proceed with this spec? (Let me know if you want to adjust anything.)"**
   - If the user requests changes, update `spec.md` and confirm.
   - Once confirmed, run Steps 2–5 **non-stop** without pausing for intermediate approvals.

## 2. Phase: Pre-Work Review (Non-Stop)
Run active `review` lenses (default: `critic` + `simplifier`; `TARGET_TYPE = pre-work`) on `spec.md` up to `rounds.review_pre` (default `1`).
- Apply pragmatic improvements directly to `spec.md` (and note 1-line reasons for skipped items). Advance automatically.

## 3. Phase: Work & Verify (Non-Stop)
Implement `spec.md` following **Human-Reviewable Minimal Diff**:
- Strictly scoped edits; no drive-by refactoring or cryptic one-line golfing.
- If hitting an unclear bug or stuck test, run `diagnostician` (blind `SYMPTOM` + `REPRO` only).
- Write/update tests per Verification Criteria.
- Run `.saw/profile.md` verification commands; fix failures up to `rounds.work_fix` (default `3`).
  *(Only halt early if verification commands still fail after `work_fix` retries and cannot proceed safely.)*

## 4. Phase: Post-Work Diff Review (Non-Stop)
Build `<work>/review-round<N>.diff` (P4) and run active `review` lenses (default: `critic` + `simplifier`; `TARGET_TYPE = post-work`; add `SPEC: <spec.md path> (reference only; review DIFF_PATH)`) up to `rounds.review_post` (default `2`):
- Fix concrete defects or diff-hygiene issues; record 1-line reasons for skipped items.
- Re-run verification commands after the final code edit.

## 5. Phase: Sync & Final Report
1. Patch `.saw/profile.md` and docs listed under `## Project docs` (and READMEs if touched/outdated) via minimal pinpoint diffs where this run made them inaccurate; never add, remove, or repoint `## Project docs` entries here.
2. Delete throwaway `.diff` / `baseline/` snapshots (keep `spec.md`).
3. Present one concise final summary:
   - What changed (files + brief summary)
   - Verification commands run & exact observed results
   - Key Goldfish suggestions applied vs skipped (1 line each)
   - Docs/profile synced (list each doc file edited)
4. If this run created, moved, or deleted a doc file, end with `Next: /saw-sync <those doc paths>` (old and new for moves; sync proposes the pointer changes).
