<!-- SAW:BEGIN -->
## Simple Agentic Workflow (SAW)
This project uses SAW. Core protocol: `.saw/protocol.md`, profile: `.saw/profile.md`, packs: `.saw/packs/`.
Available skills: `/saw-setup`, `/saw-brainstorm`, `/saw-spec`, `/saw-review`, `/saw-commit-diff`, `/saw-work`, `/saw-sync`, and `/saw-run`.
When spawning Goldfish subagents in Antigravity, use `saw-goldfish` (or fallback read-only `research` / fresh subagent instructed not to mutate files) with strictly isolated inputs per `.saw/protocol.md`. Never commit unasked.
<!-- SAW:END -->
