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
   - Docs: `README*`, `CONTRIBUTING*`, `ARCHITECTURE*`, `AGENTS.md`, `CLAUDE.md`, `docs/`.
   - Commands: `package.json`, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI workflows under `.github/workflows/`.
   - Git default branch and available packs under `.saw/packs/`.

## 2. Handle new vs existing project
- **Existing project**: Populate concise doc pointers, stack summary, and exact CI/local verification commands (`lint`, `typecheck`, `test`, `build`, `runtime`). Use `not configured` when unsure.
- **New / empty project**: Ask 2–3 quick questions max (purpose, stack, planned test command), keep unknown commands as `not configured`, and set `status: configured`.

## 3. Confirm & Save
1. Show the proposed `.saw/profile.md` draft concisely (if updating an existing configured profile, show only what changed).
2. Ask the user to confirm or tweak, then write `.saw/profile.md`.
3. Optionally offer to run the verification commands once to confirm they work.
4. End with a 1-line breadcrumb: `Next: /saw-brainstorm <topic> (explore options) or /saw-run <task> (full auto)`.
