---
name: saw-sync
description: "[5. Sync] Update .saw/profile.md, project docs, and status summaries using minimal pinpoint diffs grounded in the current code."
argument-hint: "[optional scope or doc paths]"
disable-model-invocation: true
---
# SAW Sync

Read `.saw/protocol.md` first (`phase = sync`). Update documentation and profile state strictly from the **current code on disk** (no Goldfish needed unless a project pack explicitly adds one).

## 1. Check Actual Code vs Docs
Compare current codebase reality against:
1. `.saw/profile.md` (`Project summary`, `Project docs`, `Verification commands`, `Notes & Constraints`).
2. Docs listed under `## Project docs` (and READMEs if touched/outdated).

Look specifically for drifted paths, renamed commands/flags, obsolete instructions, or new modules/features missing from summaries. Also check:
- Paths listed under `## Project docs` and `(from <path>)` sources in `## Notes & Constraints` that no longer exist, or tagged rules no longer stated in their source.
- Overview-like docs not yet listed (root-level `README*`, `ARCHITECTURE*`, `CONTRIBUTING*`, and `README*`/`index*`/`overview*`/`architecture*` at the top of `<doc-path>`); skip this check when 16 pointers are already listed. Compare normalized paths (strip backticks, split multi-path lines) so listed docs are not re-proposed; skip a missing `<doc-path>` silently.

## 2. Patch with Minimal Pinpoint Diffs
- **Never rewrite whole files** when updating docs or `profile.md`.
- Preserve existing structure, tone, and wording; edit only lines that drifted from actual code.
- If a listed doc looks obsolete or large and needs structural rework, ask before rewriting.
- Do not add, remove, or repoint `## Project docs` entries or `(from …)` rules here; route them to **Proposed** in §3.

## 3. Report
Print a concise list of what drifted and which files were updated. List missing or new pointers/sources under **Proposed (not applied)** (new pointers as `- <path>: <what it covers> — read when: <task type / dirs>`) and apply them only after the user says yes; never delete silently. End with `Next: inspect git status / git diff (ready for manual commit)`.
