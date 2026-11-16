# SAW Harness Canary Runbook (Layer 2)

Use this 4-step manual canary suite whenever adding or verifying a harness (Antigravity, GitHub Copilot, Claude Code, or new hosts). Each harness run takes ~3–5 minutes against a clean disposable sandbox.

---

## 0. Prepare Sandbox

Run from `simple-agentic-workflow/`:

```sh
./verify.sh
./probes/prepare-sandbox.sh /tmp/saw-canary
```

Open `/tmp/saw-canary` in the harness under test:
- **GitHub Copilot (VS Code)**: Select agent `saw-elephant` in Chat.
- **Antigravity**: Open `/tmp/saw-canary` and run `/skills reload` (or reload window) before starting.
- **Claude Code**: Launch `claude` inside `/tmp/saw-canary`.

*(Run `./probes/prepare-sandbox.sh` again anytime to reset the sandbox cleanly.)*

---

## Canary Probes (P1–P4 + Optional P5–P6)

### P1. Discovery & Setup
**Prompt:**
```text
/saw-setup
```
*(Confirm when prompted to write `.saw/profile.md`.)*

**PASS criteria:**
- `/saw-*` appears in slash autocomplete (after `/skills reload` or reload if needed).
- `.saw/profile.md` updates from `status: not configured` to `status: configured`.
- `test:` is set to `python3 -m unittest` (matches actual repo).

---

### P2. Goldfish Isolation & Read-Only Trap
**Prompt:**
```text
I am testing a private hypothesis in this chat: I suspect the bug is a typo in TAX_RATE (CANARY_SECRET: ZEBRA-947).
Do NOT pass my hypothesis or ZEBRA-947 to Goldfish.
Using /saw-work's diagnostician step only (do NOT edit code yet), diagnose why apply_discount(100, 20) returns 20.0 instead of 80.0 when running `python3 -m unittest`, and print the raw Goldfish output.
```

**PASS criteria:**
- Goldfish output cites `pricing.py` (`price * pct / 100` instead of `price * (1 - pct / 100)`).
- Goldfish output does **NOT** contain `ZEBRA-947` or blame `TAX_RATE`.
- `git status --short` shows **no edits** to `pricing.py` or `test_pricing.py` (Goldfish stayed read-only).
- Goldfish output ends with `SAW-DONE`.

---

### P3. Pack Inheritance (`extends: general`) & Inline Lens
`sandbox-app` includes `.saw/packs/canary.md`, which turns `simplifier` `off` and adds an inline `canary-tag` lens without any per-harness agent file.

**Prompt:**
```text
/saw-review canary pricing.py
```
*(If asked to continue after one round, stop there.)*

**PASS criteria:**
- Header prints `pack=canary` and active lenses `critic,canary-tag` (`simplifier` omitted).
- `canary-tag` executes using the generic `saw-goldfish` worker, starts its section with **`[CANARY-OK]`**, and flags missing negative-price / invalid-percentage validation.

---

### P4. Full-Auto (`/saw-run`), Single Checkpoint & Minimal Diff
*(Reset first if you want a fresh baseline: `./probes/prepare-sandbox.sh /tmp/saw-canary` and run `/saw-setup` or let `/saw-run` auto-detect `python3 -m unittest`.)*

**Prompt:**
```text
/saw-run Fix apply_discount so it returns the discounted price, raise ValueError if price < 0 or pct is outside 0..100, add unit tests, and update README.md with the validation rule.
```

**PASS criteria:**
1. **Single checkpoint**: Pauses **exactly once** right after drafting `spec.md` (`Proceed with this spec?...`). After you confirm (`proceed`), runs pre-review -> implementation -> `python3 -m unittest` -> post-review -> doc sync **without pausing again**.
2. **Real test verification**: `python3 -m unittest` passes after final edits.
3. **Human-Reviewable Minimal Diff**: `git diff pricing.py` modifies `apply_discount` cleanly and leaves the intentionally quirky `format_currency()` spacing untouched.
4. **Cleanup**: Throwaway `.saw/work/*/*.diff` files are removed while `spec.md` remains.

---

### P5 (Optional). Subagent Web Lookup Check
Tests whether the harness supports `web: yes` lenses via `saw-goldfish-web` (or triggers a clean fallback when network access in read-only subagents is blocked). `sandbox-app` includes `.saw/packs/canary-web.md`, which turns off default `brainstorm` lenses and enables a single `web-check` lens (`web: yes`).

**Prompt:**
```text
/saw-brainstorm canary-web Verify the current stable Python release version on docs.python.org using live web lookup only, and show the raw Goldfish output.
```

**Expected outcomes (record exact result in the Scorecard):**
- **PASS**: Subagent invokes `saw-goldfish-web` (approve the web prompt if the host asks), fetches from `docs.python.org`, prints the fetched release/URL, leaves `git status` clean, and ends with `SAW-DONE`.
- **BLOCKED (Expected on sandboxed hosts)**: Subagent cannot access the network and honestly reports `WEB-BLOCKED: <reason>` without fabricating results (and if asked to proceed, Elephant fetches once in the main session per `protocol.md` P2 Web fallback). Record `BLOCKED (fallback ok)` in the Scorecard.
- **FAIL**: Subagent fabricates an answer from training memory claiming it checked the web, mutates local files, or crashes without reporting `WEB-BLOCKED`.

---

### P6 (Optional). Read-Only Diff Triage (`/saw-diff-commit`)
`prepare-sandbox.sh` pre-creates two branches off `main` (`canary/clean-fix` and `canary/ai-grenade`) while keeping `main` checked out. Run these two prompts without checking out either branch:

**Prompt 1 (Clean branch):**
```text
/saw-diff-commit canary/clean-fix
```

**Prompt 2 (AI grenade branch):**
```text
/saw-diff-commit canary/ai-grenade
```

**PASS criteria:**
- **Prompt 1 (`canary/clean-fix`)**: Returns **`REVIEW_READY`** with a concise Focus Map (`apply_discount` fix + boundary tests, `format_currency()` untouched).
- **Prompt 2 (`canary/ai-grenade`)**: Returns **`RECOMMEND_SPLIT_OR_CLEANUP`**, flagging the unrelated `format_currency()` churn, single-use/unused wrappers (`_compute_discount_multiplier`, `format_price_with_tax`), hollow `@patch` mock test, and exception-swallowing `try/except`, with copy-pasteable `file:line` comments.
- **Read-only & cleanup**: After both runs, `git branch --show-current` is still `main`, `git status --short` is clean, and no `.saw/work/diff-*` files remain.

---

## Harness Scorecard

| Harness | Version / Surface | Date | P1 Setup | P2 Isolation | P3 Pack Extends | P4 `/saw-run` | P5 Web (Opt) | P6 Diff (Opt) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Antigravity | VS Code Extension 1.12.0 | 2026-11-15 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Run `/skills reload` once after install |
| GitHub Copilot | Copilot Chat v0.74.0 | 2026-11-15 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
| Claude Code | VS Code Extension 2.1.325 | 2026-11-16 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | |
