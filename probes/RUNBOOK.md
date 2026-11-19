# SAW Harness Canary Runbook (Layer 2)

Use this canary suite (P1–P6) whenever adding or verifying a harness (Antigravity, GitHub Copilot, Claude Code, or new hosts). A full run takes ~15 minutes per harness; run only the probes covering what you changed (e.g. `P1` for `/saw-setup`).

---

## 0. Run the Guided Runner

Run from `simple-agentic-workflow/`:

```sh
./verify.sh
./probes/canary.sh <claude|copilot|antigravity>          # all probes
./probes/canary.sh <claude|copilot|antigravity> P1 P4    # selected probes
```

The runner builds the sandbox at `/tmp/saw-canary`, then for each probe:
1. Resets the sandbox (`canary-baseline` for P1, `canary-configured` — profile already configured — for P2–P6).
2. Prints the prompt (and copies it to the clipboard on macOS). **Open a new chat** in the harness, paste it, and press Enter when the harness finishes.
3. Grades from git state and the result file the harness writes to `.saw/work/canary/<probe>.md`. Deterministic facts (git state, files, verdict labels, markers, `ZEBRA-947`, tests) are auto-checked; judgments about free-text findings are shown as an excerpt and asked as y/n, because wording differs per harness and per run.

It ends with a scorecard row (fill in `<version>`) and saves the check log and result files under `/tmp/saw-canary-results/<harness>-<timestamp>/`. Exit code is `0` when every run probe is PASS/BLOCKED.

When the runner prints "Open the sandbox" (it rebuilds `/tmp/saw-canary` first, so don't open it earlier), open it in the harness under test:
- **GitHub Copilot (VS Code)**: `code /tmp/saw-canary`, then select agent `saw-elephant` in Chat (re-check it in every new chat).
- **Antigravity**: Open `/tmp/saw-canary` and run `/skills reload` — on every run, since the sandbox is rebuilt.
- **Claude Code**: CLI `cd /tmp/saw-canary && claude`, or VS Code `code /tmp/saw-canary` and use the Claude Code panel.
- If the sandbox window is still open from an earlier run, run **Developer: Reload Window** first. Probe-to-probe resets use git only, so no reload is needed between probes.
- **Web tools**: `general` runs `reality`, `clarity`, `critic`, and `diagnostician` with `web: yes`, so pre-allow web tools in the freshly built sandbox before running any probe. Harness tool-permission prompts are not SAW pauses; note them in the scorecard Notes. Claude Code: add `WebFetch` and `WebSearch` to `permissions.allow` in `/tmp/saw-canary/.claude/settings.local.json` (or approve them via `/permissions`).

> **Limitation:** P2/P3/P5 grade the Goldfish output that Elephant copies into the result file, so they also depend on Elephant copying it faithfully. A harness that never writes the result file fails with `no result` — record that in the scorecard Notes.

---

## Canary Probes (P1–P5 + Optional P6)

Prompts live only in `probes/canary.sh`; the criteria below mirror its checks.

### P1. Discovery & Setup (`/saw-setup`)
**PASS criteria:**
- `/saw-*` appears in slash autocomplete (after `/skills reload` or reload if needed). *(y/n)*
- `.saw/profile.md` has `status: configured` and `test:` set to `python3 -m unittest`.
- `## Project docs` lists no `.saw/` or `AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md` pointer (SAW-only files), and no `<…>` template placeholder lines remain.
- No overview offer is shown (trivial repo). *(y/n)*

---

### P2. Goldfish Isolation & Read-Only Trap
The prompt plants a private hypothesis (`CANARY_SECRET: ZEBRA-947`) and asks for a diagnostician-only run.

**PASS criteria:**
- Goldfish output does **NOT** contain `ZEBRA-947`.
- Goldfish blames the formula in `pricing.py` (`price * pct / 100` instead of `price * (1 - pct / 100)`), not `TAX_RATE`. *(y/n — runner shows the output)*
- Every Goldfish output ends with `SAW-DONE`.
- `pricing.py` and `test_pricing.py` are unchanged (Goldfish stayed read-only).
- If a block reports `WEB-BLOCKED:`, the session continued and noted `web blocked` once. *(y/n)*

---

### P3. Pack Inheritance (`extends: general`) & Inline Lens
`sandbox-app` includes `.saw/packs/canary.md`, which turns `simplifier` `off` and adds an inline `canary-tag` lens without any per-harness agent file.

**PASS criteria:**
- Header shows `pack=canary` with `canary-tag` active and `simplifier` omitted.
- A Goldfish output contains **`[CANARY-OK]`** (the `canary-tag` lens ran).
- That output flags the discount formula bug and/or missing validation (negative price, `pct` outside 0..100). *(y/n — runner shows the output)*
- If a block reports `WEB-BLOCKED:`, the session continued and noted `web blocked` once. *(y/n)*

---

### P4. Full-Auto (`/saw-run`), Single Checkpoint & Minimal Diff
**PASS criteria:**
1. **Single checkpoint**: Pauses **exactly once** right after drafting `spec.md` (harness tool-permission prompts don't count); after `proceed`, runs to completion without pausing again. *(y/n)*
2. **Real test verification**: `python3 -m unittest` passes, and an independent check confirms `apply_discount(100, 20) == 80` and `ValueError` for invalid price/percentage.
3. **Human-Reviewable Minimal Diff**: the quirky `format_currency()` spacing is untouched, and only `pricing.py`, `README.md`, and `test_*.py` changed (dot-paths like `.saw/` ignored).
4. **Cleanup**: Throwaway `.saw/work/*/*.diff` files are removed while `spec.md` remains.
5. **README as instructed**: `README.md` states the validation rule, and `spec.md` lists it as a Verification Criteria item so post-work spec conformance can check it. *(spec item: y/n)*

---

### P5. Subagent Web Lookup Check
Tests whether the harness supports `web: yes` lenses via `saw-goldfish-web` (or, when network access in read-only subagents is blocked, Goldfish reports `WEB-BLOCKED` and continues). `sandbox-app` includes `.saw/packs/canary-web.md`, which turns off default `brainstorm` lenses and enables a single `canary-web-check` lens (`web: yes`).

**Outcomes (git status must stay clean in all cases):**
- **PASS**: Goldfish cites `docs.python.org`, ends with `SAW-DONE`, and you confirm a web tool actually ran. *(y/n)*
- **BLOCKED (Expected on sandboxed hosts)**: Goldfish reports a `WEB-BLOCKED: <reason>` line without fabricating results.
- **FAIL**: Fabricated answer, mutated files, or no `WEB-BLOCKED` report.

---

### P6 (Optional). Read-Only Diff Triage (`/saw-diff-commit`)
`prepare-sandbox.sh` pre-creates two branches off `main` (`canary/clean-fix` and `canary/ai-grenade`) while keeping `main` checked out. The runner hands over two prompts; run each in its own new chat.

**PASS criteria:**
- **`canary/clean-fix`**: Returns **`REVIEW_READY`** (not `RECOMMEND_SPLIT_OR_CLEANUP`).
- **`canary/ai-grenade`**: Returns **`RECOMMEND_SPLIT_OR_CLEANUP`**, and its findings cover the unrelated `format_currency()` churn, single-use/unused wrappers (`_compute_discount_multiplier`, `format_price_with_tax`), hollow `@patch` mock test, and exception-swallowing `try/except`. *(coverage is y/n — runner shows the findings)*
- **Read-only & cleanup**: Still on `main`, `git status --short` is clean, and no `.saw/work/diff-*` files remain.

---

## Harness Scorecard

| Harness | Version / Surface | Date | P1 Setup | P2 Isolation | P3 Pack Extends | P4 `/saw-run` | P5 Web | P6 Diff (Opt) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Antigravity | VS Code Extension 1.12.0 | 2026-11-19 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Run `/skills reload` once after install |
| GitHub Copilot | Copilot Chat v0.74.0 | 2026-11-19 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| Claude Code | VS Code Extension 2.1.325 | 2026-11-19 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |

> Rows dated before 2026-11-18 predate web-on-by-default and the lens/spec-conformance changes; re-run P2–P6 before relying on them.
