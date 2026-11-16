<!-- SAW:BEGIN -->
## Simple Agentic Workflow (SAW)
This project uses SAW. Core protocol: `.saw/protocol.md`, profile: `.saw/profile.md`, packs: `.saw/packs/`.
- **Start / Auto**: `/saw-setup`, `/saw-run`, `/saw-help`
- **Manual Lifecycle**: `/saw-brainstorm` → `/saw-spec` → `/saw-review` → `/saw-work` → `/saw-sync`
- **Read-Only Diffs**: `/saw-diff-commit`, `/saw-diff-files`
When spawning Goldfish subagents in Antigravity, use `saw-goldfish` (or fallback read-only `research` / fresh subagent instructed not to mutate files) with strictly isolated inputs per `.saw/protocol.md`. Never commit unasked.
<!-- SAW:END -->
