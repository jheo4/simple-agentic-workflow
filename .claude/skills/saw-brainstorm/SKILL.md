---
name: saw-brainstorm
description: "[1. Brainstorm] Screen ideas or decide what task to tackle next using balanced diverge + reality-check Goldfish perspectives."
argument-hint: "[pack] <topic or problem>"
disable-model-invocation: true
---
# SAW Brainstorm

Read `.saw/protocol.md` first and follow P0–P2 (`phase = brainstorm`). No code edits in this skill.

## 1. Frame the Seed
From the user's input (plus `.saw/profile.md` and key repo files if relevant), craft a short `SEED`:
```text
SEED
- Thought: <what the user wants to explore>
- Context: <relevant area of the repo or constraint>
- Goal: <what kind of tasks/options would help>
```
If the prompt is extremely vague, ask 1–2 quick clarifying questions; otherwise proceed directly to Goldfish without unnecessary ping-pong.

## 2. Run Active `brainstorm` Lenses
Run all `active` `brainstorm` lenses from the resolved pack (default `general`: `incremental`, `reframe`, `zoom`, `reality`) in parallel.
Pass ONLY `LENS` + `PROFILE` + `SEED` (and `FOCUS` if defined in the pack row).

## 3. Synthesize & Recommend
Deduplicate overlapping ideas and present a clean, scannable brief:
- **Recommended Picks (Top 2–3)**: Option name, angle (`incremental` / `reframe` / `zoom`), what changes, and upside/trade-off.
- **Reality Check (`reality`)**: Key risks, scope cuts, or reasons not to build something.
- `Next: /saw-spec <pick> (refine spec) or /saw-run <pick> (full auto)` — or ask to explore another angle.
