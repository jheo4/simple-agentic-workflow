---
name: saw-help
description: "[Help] Show the SAW workflow map, per-phase default Goldfish lenses, or recommend the right /saw-* command for a goal."
argument-hint: "[optional goal or pack]"
disable-model-invocation: true
---
# SAW Help

Read-only guide for SAW skills and Goldfish lenses. Do not spawn Goldfish, edit files, or auto-run another skill.

## 1. Parse Input & Resolve Pack
- `.saw/` and `.saw/protocol.md` are optional.
- If input is empty, or a single token matching `.saw/packs/<name>.md` or `general`: show the **Workflow & Lens Guide** (Step 2) for that pack (default: `default-pack` from `.saw/profile.md`, fallback `general`).
- Otherwise treat the input as `<goal>` (if its leading word matches `.saw/packs/<name>.md`, use that pack for context and treat the rest as `<goal>`) and go to Step 3.

When resolving a pack from `.saw/packs/<pack>.md`, read `.saw/protocol.md` (P0) when present and follow `extends:` up to depth 3 with cycle detection; if `.saw/`, the pack, or an ancestor is missing or cyclic, fall back to the embedded `general` defaults below and note it briefly.

### Embedded `general` Defaults (`rounds`: `spec=1, review_pre=1, work_fix=3, review_post=2, review_manual=2`)
| Phase | Skill | Default Goldfish Lenses | Purpose |
|---|---|---|---|
| Setup | `/saw-setup` | none | Initialize/refresh `.saw/profile.md` |
| `brainstorm` | `/saw-brainstorm` | `incremental`, `reframe`, `zoom`, `reality` (web) (4 parallel) | Diverge + reality-check task selection |
| `spec` | `/saw-spec` | `clarity` (web) (1) | Tighten scope, edge cases, verification |
| `review` | `/saw-review` | `critic` (web), `simplifier` (2 parallel; `pre-work` / `post-work`) | Catch defects & enforce Minimal Diff |
| `work` | `/saw-work` | `diagnostician` (web) (`on_demand`) + `review` (`critic` (web), `simplifier` post-work) | Implement, verify, blind-debug if stuck |
| `sync` | `/saw-sync` | none | Sync `.saw/profile.md` & docs to disk |
| Full Auto | `/saw-run` | `spec` (`clarity` (web)) → 1 checkpoint → `review` + `work` + `sync` | End-to-end automation |
| `review` (PR/Git) | `/saw-diff-commit` | `critic` (web), `simplifier` (read-only) | Read-only commit/branch/PR triage |
| `diff` (Files/Dirs) | `/saw-diff-files` | `concept`, `direction`, `detail` (3 parallel) | Macro, mid, detail file/dir comparison |

## 2. Print Workflow & Lens Guide
Present concisely:
1. **3-Tier Map**:
   - **Start / Auto**: `/saw-setup` (once) → `/saw-run <task>` (daily all-in-one) · `/saw-help` (this guide)
   - **Manual Lifecycle**: `/saw-brainstorm` → `/saw-spec` → `/saw-review` → `/saw-work` → `/saw-sync`
   - **Read-Only Diffs**: `/saw-diff-commit <range|branch|sha|#pr|url>` · `/saw-diff-files <left> <right> [focus]`
2. **Goldfish Lenses per Phase** (for the resolved pack, listing `active`, `on_demand`, `off`, `web: yes`, and `rounds`).
3. If `.saw/` is absent, note `./install.sh <dir>`; if `.saw/profile.md` says `status: not configured`, suggest `Next: /saw-setup`.

## 3. Recommend for `<goal>`
Pick the **single best** `/saw-*` command for `<goal>`, explain in 1–2 lines why (plus which Goldfish lenses will run), and print a ready-to-run command example (`Next: /saw-...`).
