# SAW Project Profile
status: configured

## Settings
default-pack: general
base-branch: main
doc-path: README.md

## Project summary
- Purpose: Simple Agentic Workflow (SAW) — lightweight, project-local Elephant–Goldfish workflow and multi-harness installer for GitHub Copilot, Claude Code, and Antigravity.
- Stack: Bash (`install.sh`, `verify.sh`, `probes/prepare-sandbox.sh`) and Markdown skills/templates/adapters (plus Python `unittest` fixtures in `probes/sandbox-app/`).

## Project docs
- `README.md`: Architecture, workflow phases, `general` pack & inheritance, installation, and verification instructions.
- `probes/RUNBOOK.md`: Layer 2 manual harness canary suite (`P1`–`P6`) and harness scorecard.
- `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md`: Harness adapter instruction blocks.

## Verification commands
lint: not configured
typecheck: not configured
test: ./verify.sh
build: not configured
runtime: not configured

## Notes & Constraints
- Canonical sources live in `templates/`, `skills/`, and `adapters/`; `.saw/`, `.github/`, `.claude/`, `.agents/`, `AGENTS.md`, and `CLAUDE.md` are installed/dogfooded via `./install.sh . --update`.
- Never overwrite `.saw/profile.md` or custom `.saw/packs/*.md` / `.saw/lenses/*.md` during updates.
- `.saw/work/` is gitignored for ephemeral specs and diffs.
