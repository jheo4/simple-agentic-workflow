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

Look specifically for drifted paths, renamed commands/flags, obsolete instructions, or new modules/features missing from summaries.

## 2. Patch with Minimal Pinpoint Diffs
- **Never rewrite whole files** when updating docs or `profile.md`.
- Preserve existing structure, tone, and wording; edit only lines that drifted from actual code.
- If a listed doc looks obsolete or large and needs structural rework, ask before rewriting.

## 3. Report
Print a concise list of what drifted, which files were updated, and end with `Next: inspect git status / git diff (ready for manual commit)`.
