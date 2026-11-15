# Simple Agentic Workflow (SAW)

A lightweight, project-local (`.envrc`-style) agentic development workflow inspired by the **Elephant–Goldfish** idea, stripped of heavy ceremonies so AI actually improves productivity.

Works out of the box inside any project across **GitHub Copilot**, **Claude Code**, and **Antigravity**.

---

## Core Idea

- **Elephant (your main session)**: Holds conversation context, writes specs and code, runs real verification commands, and communicates with you.
- **Goldfish (automated fresh-context helpers)**: Read-only subagents with zero prior chat history that inspect isolated inputs (seed, spec, diff, or symptom+repro) through focused lenses—catching blind spots without burying you in multi-stage approval reports.
- **Human-Reviewable Minimal Diff**: Changes stay tightly scoped, natural, and readable so human code review takes minutes instead of creating review fatigue.

*(Trivial fixes like typos or one-line tweaks don't need SAW—just ask your agent directly, or SAW will fast-path them.)*

---

## Workflow Phases & Skills

| Skill | Phase | What It Does |
|---|---|---|
| `/saw-setup` | Setup | Scans an existing repo (or interviews briefly for a new one) to create `.saw/profile.md`. |
| `/saw-brainstorm [pack] <topic>` | Brainstorm | Runs 4 parallel lenses (`incremental`, `reframe`, `zoom`, `reality` suppressor) to pick the right task. |
| `/saw-spec [pack] <task>` | Task Spec | Drafts a concise spec with edge cases + verification criteria, refined by `clarity`. |
| `/saw-review [pack] [spec\|diff]` | Review | Runs `critic` + `simplifier` on a spec or pending diff and applies pragmatic fixes. |
| `/saw-commit-diff [pack] <target>` | Diff Triage | Compares commits, branches, or a PR read-only without checkout; outputs summary + SAW commentary. |
| `/saw-work [pack] <spec\|task>` | Work | Implements cleanly, runs test/lint commands, optional blind `diagnostician`, then post-work diff review. |
| `/saw-sync` | Sync | Patches `.saw/profile.md` and drifted docs to match **current code on disk** via minimal diffs. |
| `/saw-run [pack] <task>` | **Full Auto** | Drafts `spec` → **stops ONCE for confirmation** → runs pre-review, implementation, tests, post-review, and sync **non-stop**. |

---

## Default `general` Pack & Inheritance

Located in `.saw/packs/general.md`:

- **brainstorm** (`4` parallel): `incremental` (minimal high-leverage start), `reframe` (alternative angle), `zoom` (zoom-out + zoom-in), `reality` (suppressor / anti-bloat).
- **spec** (`1`): `clarity` (ambiguities, edge cases, verification criteria).
- **review** (`2` parallel, shared for pre-work specs & post-work diffs): `critic` (bugs, risks, missing tests) + `simplifier` (reuse, anti-bloat, **Human-Reviewable Minimal Diff**).
- **work** (`on_demand`): `diagnostician` (blind root-cause analysis from symptom + repro only when stuck or fixing unclear bugs).

### Customizing via `extends: general`

Create `.saw/packs/<your-pack>.md` (optional custom prompt file in `.saw/lenses/<lens>.md`):

```markdown
# SAW Pack: backend-sec
description: General workflow with security review and no reframe brainstorm
extends: general

| phase | lens | use | web | focus |
|---|---|---|---|---|
| brainstorm | reframe | off | no | - |
| review | security | active | no | auth, permissions, injection, secret/PII handling |
```

Then run `/saw-run backend-sec add password reset endpoint` (or set `default-pack: backend-sec` in `.saw/profile.md`). Because read-only `saw-goldfish` workers load lenses dynamically from `.saw/`, custom packs work identically in Copilot, Claude Code, and Antigravity with zero per-harness agent boilerplate.

---

## Project-Local Installation (`.envrc`-style)

Install SAW directly into any repository so whichever supported harness opens that folder, SAW is ready automatically:

```sh
# Install all 3 harness adapters (default)
./install.sh /path/to/your-project

# Or pick specific harnesses
./install.sh /path/to/your-project --targets copilot,claude,antigravity

# Later updates (preserves .saw/profile.md and custom packs/lenses)
./install.sh /path/to/your-project --update
```

Installed layout inside `<your-project>/`:

```text
<your-project>/
├── .saw/               # Single source of truth (protocol, profile, packs, lenses, gitignored work/)
├── .github/            # GitHub Copilot adapter (copilot-instructions block, skills, saw-elephant/goldfish agents)
├── .claude/            # Claude Code adapter (CLAUDE.md block, skills, read-only saw-goldfish agents)
└── .agents/            # Antigravity adapter (AGENTS.md block, skills, .agents/plugins/saw/)
```

### Usage by Harness
- **GitHub Copilot (VS Code)**: Select the **`saw-elephant`** agent in Chat, then run `/saw-setup` or `/saw-run ...`.
- **Claude Code**: Run `/saw-setup` or `/saw-run ...` directly in the project directory.
- **Antigravity**: Run `/skills reload` (or reload the window) once after installing, then run `/saw-setup` or `/saw-run ...` directly in the project directory (requires a surface with subagent support such as Antigravity CLI, App, or IDE Extension).

---

## Verification & Harness Canary Probes

- **Static & installer check (Layer 1)**: Run `./verify.sh` to validate skill frontmatter, `general.md` lens references, multi-target installs, and `--update` profile preservation.
- **Interactive harness probes (Layer 2)**: Run `./probes/prepare-sandbox.sh` and follow [`probes/RUNBOOK.md`](probes/RUNBOOK.md) to verify skill discovery, Goldfish context isolation, pack inheritance, and `/saw-run` end-to-end behavior in any harness.
