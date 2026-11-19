# SAW Core Protocol

Simple Agentic Workflow (SAW) is a lightweight dual-role workflow:
- **Elephant** (you, the main session): Holds conversation context, writes specs and code, runs tests, and talks to the user.
- **Goldfish** (fresh read-only subagent): Runs with zero chat history and sees only the target input + its lens instructions.

Do not over-ceremonialize. Keep outputs short, decisions practical, and diffs human-reviewable.

## Core Principles

1. **Productive, not bureaucratic**: Never halt for multi-round approval reports unless a skill explicitly asks for a human checkpoint.
2. **Human-Reviewable Minimal Diff**:
   - Keep code and doc changes tightly scoped to the task. No drive-by refactoring, unrelated formatting/import churn, or wholesale file rewrites.
   - Never sacrifice clarity for line-count tricks (no cramped one-liners or cryptic golfing). Optimize for a human reading the diff cleanly in a few minutes.
3. **Verify against reality**: Run actual test/lint/check commands from `.saw/profile.md`. Never claim a test passed without running it.
4. **Fast-path trivial edits**: For single-line config tweaks, typos, comments, or dead-code removal, skip Goldfish calls and run relevant checks directly.

## P0. Parse Arguments & Resolve Pack

Skill arguments have the optional form `[pack] <task or target>`.
1. List `.saw/packs/*.md`. If the first word matches a pack filename (without `.md`), use that pack and treat the remainder as the task/target.
2. Otherwise use `default-pack` from `.saw/profile.md` (fallback: `general`) and treat the whole input as the task/target.
3. **Resolve inheritance** (`extends: <parent>`, max depth 3):
   - Start from the root ancestor and apply child overrides:
     - Same `(phase, lens)` replaces the parent row.
     - New `(phase, lens)` adds a row.
     - `use: off` removes that row.
     - Child `rounds` overrides parent `rounds` per key (`spec`, `review_pre`, `work_fix`, `review_post`, `review_manual`).
4. Print a compact header at skill start:
   `[SAW] pack=<pack> | phase=<phase> | lenses=<comma-separated active lenses or none>`

## P1. Context & Work Directory

1. Read `.saw/profile.md` and only the project docs listed under `## Project docs` relevant to the task.
2. If `profile.md` says `status: not configured`:
   - In `/saw-setup`, run full setup.
   - In other skills, do a quick read of obvious repo files/package scripts (`package.json`, `pyproject.toml`, etc.) or ask one quick question if verification commands are missing—never guess destructive commands.
3. For multi-step tasks (`/saw-spec`, `/saw-work`, `/saw-run`), create `.saw/work/<yyyy-mm-dd>-<slug>/` to store `spec.md` and throwaway `review-round<N>.diff` / `baseline/` snapshots.

## P2. Calling Goldfish (Harness-Agnostic Isolation)

Every lens runs through a fresh read-only Goldfish subagent.

- **How to spawn by harness**:
  - **GitHub Copilot**: Run `saw-goldfish` (or `saw-goldfish-web` if `web: yes`).
  - **Claude Code**: Spawn `.claude/agents/saw-goldfish.md` (or `saw-goldfish-web` if `web: yes`).
  - **Antigravity**: Spawn `saw-goldfish` (or `saw-goldfish-web` when `web: yes`) via `invoke_subagent` (if unavailable in the active surface, spawn a fresh read-only subagent explicitly instructed not to edit files or run mutations, and to read and follow `.agents/plugins/saw/agents/saw-goldfish(-web).md`; note that the built-in `research` subagent has no network access).
  - **Web fallback**: If a `web: yes` Goldfish reports `WEB-BLOCKED` (including a denied web permission), keep its output (no re-spawn), continue, and note `web blocked` once per skill run.
- **Unverified findings**: Before acting on an `(unverified: external)` finding, verify it in the main session (web, official docs, or `--help`/`--version` of an installed third-party binary on PATH; never repo scripts, wrappers, or make/npm targets, and never by running the unfamiliar command). Otherwise report it with the marker; it does not count toward verdicts or the "one more round?" prompt. In `/saw-run`, skip a check that would need a new permission and record a 1-line reason (P3).
- **Strict input isolation**:
  Pass ONLY:
  1. `LENS`: `.saw/lenses/<lens>.md` (if present) and/or inline `FOCUS: <pack row focus>`
  2. `PROFILE`: `.saw/profile.md` (so Goldfish knows relevant doc pointers)
  3. `TARGET`: Only the phase-specific target (e.g., `SEED`, `SPEC`, `DIFF_PATH`, or `SYMPTOM` + `REPRO`). Post-work review in `/saw-work` and `/saw-run` adds the task's spec, if any, as `SPEC: <path> (reference only; review DIFF_PATH)`.
  Never pass chat history, your personal hunch/hypothesis, other Goldfish outputs, or prior-round rebuttals.
- **Parallelism**: Run independent lenses in the same phase/round in parallel when the harness supports it.

## P3. Loop Policy (Pragmatic Auto vs Interactive)

Goldfish outputs end cleanly with one line:
- `SAW-DONE` (for `brainstorm`, `diff`, and `diagnostician`)
- `SAW-STATUS: OK` or `SAW-STATUS: SUGGEST` (for `spec` and `review`)

How Elephant handles `SUGGEST` depends on how the skill was invoked:
- **Inside `/saw-run` (Full Auto mode)**:
  - Pragmatic loop within the pack's `rounds` cap:
    - Apply clearly valid improvements directly to the spec or code.
    - For suggestions you intentionally skip, record a 1-line factual reason (user requirement, out of scope, trade-off).
    - Re-run only up to the round limit (`spec=1`, `review_pre=1`, `review_post=2`), then **automatically advance** without pausing the user.
- **Inside standalone manual skills (`/saw-review`, `/saw-spec`, `/saw-work`)**:
  - Within `rounds`, apply fixes and loop if useful.
  - If `rounds` is reached and non-trivial suggestions remain unapplied, ask the user concisely: **"Run one more round, or wrap up here?"**
- **Post-work (both modes)**: Change the spec only on user request; a spec-conformance finding already skipped with a recorded reason does not count as an open suggestion.

## P4. Diff Packaging for Code Review

Goldfish has no shell, so Elephant builds `.saw/work/<task>/review-round<N>.diff`:
- **Git repo**: capture `git status -s`, `git diff`, `git diff --cached`, `git diff <base-branch>...HEAD`, plus full contents of new untracked non-ignored files relevant to the task.
- **Non-git directory**: snapshot touched files to `<work>/baseline/<path>` before first edit and generate `diff -u` + new file contents.
Delete temporary `.diff` and `baseline/` files when `/saw-work` or `/saw-run` finishes; keep `spec.md` unless asked to delete.

## P5. Never Commit Unasked

Never run `git commit` or `git push` unless the user explicitly asks you to.
