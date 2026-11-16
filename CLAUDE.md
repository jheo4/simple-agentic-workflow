<!-- SAW:BEGIN -->
## Simple Agentic Workflow (SAW)
This project uses SAW. Core protocol: `.saw/protocol.md`, profile: `.saw/profile.md`, packs: `.saw/packs/`.
- **Start / Auto**: `/saw-setup`, `/saw-run`, `/saw-help`
- **Manual Lifecycle**: `/saw-brainstorm` → `/saw-spec` → `/saw-review` → `/saw-work` → `/saw-sync`
- **Read-Only Diffs**: `/saw-diff-commit`, `/saw-diff-files`
During `/saw-*` runs, spawn `saw-goldfish` (or `saw-goldfish-web`) only with isolated inputs as defined in `.saw/protocol.md`. Never commit unasked.
<!-- SAW:END -->
