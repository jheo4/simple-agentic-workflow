---
name: saw-setup
description: "[Start] Set up or refresh the SAW project profile (.saw/profile.md) for a new or existing project."
argument-hint: "[optional notes or target stack]"
disable-model-invocation: true
---
# SAW Setup

Initialize or refresh `.saw/profile.md` without calling Goldfish. Works for both brand-new and existing repositories.

## 1. Read state
1. Check `.saw/protocol.md`, `.saw/packs/`, and `.saw/profile.md`.
2. Scan the repository lightly (do not modify source code):
   - Docs: `README*`, `CONTRIBUTING*`, `ARCHITECTURE*`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `<doc-path>` (default `docs/`; on first setup, if `docs/` is missing but a folder like `doc/` or `documentation/` exists, propose it as `doc-path`).
   - Commands: `package.json`, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI workflows under `.github/workflows/`.
   - Git default branch and available packs under `.saw/packs/`.

## 2. Handle new vs existing project
- **Existing project**: Populate stack summary, exact CI/local verification commands (`lint`, `typecheck`, `test`, `build`, `runtime`; use `not configured` when unsure), and:
  - **Doc pointers**: ≤16 entries as `- <path>: <what it covers> — read when: <task type / dirs>`, preferring overview/index docs over leaf docs; never list SAW's own files (`.saw/`, SAW-only adapter files).
  - **Hard rules**: Copy verbatim (one line each) must/never/always rules (edit/verification rules before style) from `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, and `CONTRIBUTING*` into `## Notes & Constraints`, each tagged `(from <path>)`.
    - Ignore content inside `<!-- SAW:BEGIN -->`…`<!-- SAW:END -->`; list these files as doc pointers only if project content remains outside the markers.
    - The cap is ≤6 `(from …)`-tagged lines in total (untagged lines don't count). On refresh, keep existing untagged lines and skip rules already present (same tag + text).
  - **Structure overview (opt-in)**: If no README/overview doc describes the directory layout or entry points, and source spans more than one directory or more than 8 files (excluding `.saw/`, hidden dirs, docs, tests), offer in the step-3 draft (default No) to write `<doc-path>/overview.md` with a directory map and entry points from current code. Never overwrite an existing file or edit README; if accepted, add it as a doc pointer.
- **New / empty project**: Ask 2–3 quick questions max (purpose, stack, planned test command) and keep unknown commands as `not configured`.

## 3. Confirm & Save
1. Show the proposed `.saw/profile.md` draft concisely (if updating an existing configured profile, show only what changed), plus the overview offer if any. Lines identical to the `templates/profile.md` placeholders are always replaced, never kept as existing content; write `- none found` in any list section that would otherwise be empty.
2. Ask the user to confirm or tweak, then write `.saw/profile.md` with `status: configured` (and `overview.md` only if accepted).
3. Optionally offer to run the verification commands once to confirm they work.
4. End with a 1-line breadcrumb: `Next: /saw-brainstorm <topic> (explore options) or /saw-run <task> (full auto)`.
