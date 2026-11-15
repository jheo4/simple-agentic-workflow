---
name: saw-spec
description: Clarify and structure a concrete task specification with scope, edge cases, and verification criteria.
argument-hint: "[pack] <task description or brainstorm pick>"
disable-model-invocation: true
---
# SAW Spec

Read `.saw/protocol.md` first and follow P0–P3 (`phase = spec`). No production code edits in this skill.

## 1. Inspect Relevant Code
Read the existing files likely touched by the task so the spec aligns with actual repo structure and reusable utilities.

## 2. Draft `<work>/spec.md`
Keep it concise (under ~50 lines when possible):
```markdown
# Spec: <task title>
- Goal: <1–2 sentences>
- Scope:
  - In: <bullet list>
  - Out: <explicitly excluded>
- Likely Files: <paths>
- Behavior & Edge Cases: <concrete behavior, error/empty states>
- Verification Criteria: <exact tests, commands, or observable checks proving completion>
```

## 3. Goldfish Clarity Check (`spec` lenses)
Run active `spec` lenses from the resolved pack (default: `clarity`) in parallel, passing ONLY `LENS` + `PROFILE` + `SPEC` + `LIKELY FILES`.
- Within `rounds.spec` (default `1`), revise `spec.md` for valid gaps or note 1-line reasons for skipped suggestions.
- Per P3 (manual mode): if `SAW-STATUS: SUGGEST` remains after `rounds.spec`, summarize open points and ask whether to run one more check or finalize.

## 4. Present Spec
Show the clean final `spec.md` path and summary, ready for `/saw-review` or `/saw-work`.
