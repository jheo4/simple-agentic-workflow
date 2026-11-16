# Customizing Packs & Lenses

> Back to [README](../README.md) · Related: [Architecture & Design](architecture.md) · Core spec: [`templates/protocol.md`](../templates/protocol.md)

Just as different projects need different test suites, they also need different workflow and review criteria. Rather than writing every rule from scratch, SAW ships a universal `general` pack that any project can inherit (`extends: general`)—toggling unneeded lenses off or adding domain-specific ones in a few lines.

After running `./install.sh /path/to/your-project`, SAW stores all configuration inside `.saw/`:
- **Pack** (`.saw/packs/<name>.md`): A routing table that maps workflow phases to Goldfish lenses and sets loop caps (`rounds`).
- **Lens** (`.saw/lenses/<name>.md` or inline `focus`): A read-only stance prompt telling a fresh Goldfish subagent what to inspect.

SAW separates **SAW-owned templates** (refreshed on `--update`) from **project-owned customizations** (never overwritten). Instead of editing `.saw/packs/general.md` or `.saw/protocol.md` directly, extend `general` with a project pack.

---

## 1. Default `general` Pack Reference

Defined in [`templates/packs/general.md`](../templates/packs/general.md) (installed to `.saw/packs/general.md`):

- **Default `rounds`**: `spec=1` (`/saw-spec`, `/saw-run` spec check), `review_pre=1` (`/saw-run` pre-work spec review), `work_fix=3` (`/saw-work`, `/saw-run` test-fix retries), `review_post=2` (`/saw-work`, `/saw-run` post-work diff review), `review_manual=2` (standalone `/saw-review`).

| Phase | Used By | Lenses | `use` | Focus |
|---|---|---|---|---|
| `brainstorm` | `/saw-brainstorm` | `incremental`, `reframe`, `zoom`, `reality` | `active` (4 parallel) | Minimal start, reframe, zoom-out/in, suppressor |
| `spec` | `/saw-spec`, `/saw-run` | `clarity` | `active` | Ambiguities, edge cases, verification criteria |
| `review` | `/saw-review`, `/saw-work`, `/saw-run`, `/saw-diff-commit` | `critic`, `simplifier` | `active` (2 parallel) | Bugs/regressions/tests + Minimal Diff |
| `work` | `/saw-work`, `/saw-run` | `diagnostician` | `on_demand` (only when stuck/unclear bug) | Blind root-cause diagnosis (`SYMPTOM` + `REPRO`) |
| `diff` | `/saw-diff-files` | `concept`, `direction`, `detail` | `active` (3 parallel) | Macro concept, mid direction, detail drift |

---

## 2. Creating a Custom Pack (`extends: general`)

Create `.saw/packs/<pack-name>.md`:

```markdown
# SAW Pack: backend-sec
description: General workflow with security review, live doc lookup, and no reframe brainstorm
extends: general
rounds: review_post=3

| phase | lens | use | web | focus |
|---|---|---|---|---|
| brainstorm | reframe | off | no | - |
| review | security | active | yes | auth, permissions, injection, secret/PII handling |
```

### Resolution Rules (Protocol P0 & P2)
- **Inheritance (`extends:`)**: Resolves root ancestor → child up to depth 3 (with cycle detection); child rows replace matching `(phase, lens)` rows, new rows are added, and `use: off` removes a lens.
- **`rounds:`**: Overrides only the specified loop keys (`spec`, `review_pre`, `work_fix`, `review_post`, `review_manual`), leaving other parent keys intact.
- **`web: yes` (Rule P2 in [`templates/protocol.md`](../templates/protocol.md))**: Defaults to `no`; when `yes`, spawns `saw-goldfish-web` so Goldfish can look up live docs (if network access is blocked in a sandboxed host, Elephant fetches once in the main session and passes the excerpt).
- **Invoking a pack**: Pass the pack name as the first argument (`/saw-run backend-sec add password reset` or `/saw-diff-commit backend-sec #123`), or set `default-pack: backend-sec` under `## Settings` in `.saw/profile.md`.

---

## 3. Writing a Custom Lens (`.saw/lenses/<lens>.md`)

Adding a `.md` file is **optional**—when omitted, Goldfish runs in **inline lens mode**, driven solely by the pack row's `focus` column. For deeper rules, create `.saw/lenses/<lens>.md` (see [`templates/lenses/clarity.md`](../templates/lenses/clarity.md) or [`templates/lenses/simplifier.md`](../templates/lenses/simplifier.md) for built-in examples; custom `review` lenses receive `TARGET_TYPE = pre-work | post-work` so they work on both specs and diffs):

```markdown
# Lens: security
You are a fresh, read-only Goldfish in the **review** phase (`TARGET_TYPE`: `pre-work` or `post-work`).
Do not modify any files or ask questions.

- Check auth/authz boundaries, injection risks, and secret/PII handling.
- Cite `file:line` and concrete fixes, or write `No security issues.`

Last line, exactly one of:
- `SAW-STATUS: OK`
- `SAW-STATUS: SUGGEST`
```

Required final line:
- **`brainstorm` / `diff` phases, or `diagnostician` (`work` phase)**: `SAW-DONE`
- **`spec` / `review` phases**: `SAW-STATUS: OK` or `SAW-STATUS: SUGGEST`

---

## 4. Upgrade Safety (`./install.sh <dir>`)

- **Without `--update` (`UPDATE=0`)**: Existing modified SAW-owned files are skipped as conflicts (`conflicts`) and retired SAW skills are left untouched.
- **With `--update` (`UPDATE=1`)**:
  - **Preserved (Project-Owned)**: `.saw/profile.md`, custom `.saw/packs/*.md` (other than `general.md`), custom `.saw/lenses/*.md`, custom user skills (including custom `saw-*`), and instructions outside `<!-- SAW:BEGIN -->...<!-- SAW:END -->`.
  - **Refreshed (SAW-Owned)**: `.saw/protocol.md`, `.saw/packs/general.md`, built-in `.saw/lenses/*.md`, built-in `saw-*` skills/agents, `SAW` instruction blocks, plus pruning retired built-in SAW skills (configured in [`install.sh`](../install.sh)).
