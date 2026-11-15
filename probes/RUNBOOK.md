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

## Canary Probes (P1–P4 + Optional P5)

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
Run only if testing a custom pack with `web: yes`:
- Verify whether `saw-goldfish-web` can fetch/search an external doc URL, and note whether the harness prompts for approval or blocks network access inside read-only subagents.

---

## Harness Scorecard

| Harness | Version / Surface | Date | P1 Setup | P2 Isolation | P3 Pack Extends | P4 `/saw-run` | P5 Web (Opt) | Notes |
|---|---|---|---|---|---|---|---|---|
| Antigravity | | | | | | | | |
| GitHub Copilot | | | | | | | | |
| Claude Code | | | | | | | | |
