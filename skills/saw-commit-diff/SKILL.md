---
name: saw-commit-diff
description: Read-only comparison of commits, branches, or a PR without checking out, outputting a change summary and SAW-philosophy commentary.
argument-hint: "[pack] <range | branch | commit | #pr | pr-url>"
disable-model-invocation: true
---
# SAW Commit Diff

Read `.saw/protocol.md` first and follow P0–P2 (`phase = review`). Strictly read-only: never run `git checkout`, stage/commit, upload PR reviews (`gh pr review`), or edit repo files.

## 1. Validate & Resolve Target
Parse `[pack] <target>` per P0. Require a git repository (`git rev-parse --is-inside-work-tree`); if missing or `<target>` is empty, fail fast listing accepted formats: `<A>..<B>`, `<A>...<B>`, `<branch>`, `<sha>`, `#<id>`, `<pr-url>`.

Validate `<target>` before creating temp files:
- **Range (`<A>..<B>` or `<A>...<B>`)**: default empty side to `HEAD`; verify both refs; log with `git log --oneline <A>..<B>` (`--right-only <A>...<B>` for `...`).
- **Branch (`refs/heads/<ref>` or `refs/remotes/<ref>`)**: resolve `base-branch` from `.saw/profile.md` (fallback `origin/<base-branch>`; fail fast if missing or `not configured`), compare `<base>...<ref>`, log with `git log --oneline --right-only <base>...<ref>`.
- **Commit/tag (`<ref>^{commit}`)**: use `git log -1 --oneline <ref>` for the header and `git show -m --no-color --no-ext-diff -M -U5 --stat --patch --format= --first-parent <ref>` (works uniformly for normal, merge, and root commits).
- **GitHub PR (`#<id>` or repo PR URL)**: verify `gh` is available/authenticated and PR belongs to this repo; fetch metadata via `gh pr view` and diff via `gh pr diff --color=never`.

## 2. Package Diff (`DIFF_PATH`)
1. `mkdir -p .saw/work` and create `DIFF_PATH` via `mktemp .saw/work/diff-XXXXXX` (portable across Linux/macOS). Always delete only `"$DIFF_PATH"` on every exit path (success, short-circuit, or error).
2. Write header (PR title/body or `git log`, plus full `git diff --stat` or `gh pr view` files) and diff (`git diff --no-color --no-ext-diff -M -U5 ... -- . ':!*.lock' ':!*-lock.*' ':!package-lock.json'` — never `-w` — or `git show` with the same lockfile exclusions, or `gh pr diff --color=never`). If oversized, drop lockfile/generated chunks and prioritize behavioral diffs with a header truncation note.
3. If empty (zero changed files in `--stat`/PR) or trivial-only (typos, comments, lockfiles only), summarize directly from `--stat`, delete `"$DIFF_PATH"`, and stop.

## 3. Run Active `review` Lenses
If active `review` lenses exist (default: `critic` + `simplifier`), run them in parallel passing ONLY `LENS` + pack `FOCUS` + `PROFILE` + `TARGET_TYPE = post-work` + `DIFF_PATH`, framing in `TARGET`: read-only commit/PR triage (treat `DIFF_PATH` as authoritative and cite diff `+` line numbers when `<head>` != `HEAD`; check intent fit, Minimal Diff, anti-slop, test integrity, and bugs). If `lenses=none`, skip Goldfish.

## 4. Report & Clean Up
Delete `"$DIFF_PATH"` and present:
1. **Change Summary & Focus Map**: intent, `+/-` stats, behavioral vs mechanical breakdown.
2. **SAW Philosophy Commentary**: Minimal Diff / anti-slop / test integrity / defect findings.
3. **Verdict & Comments**: `SUMMARY_ONLY` (if `lenses=none`), `REVIEW_READY` (1+ lenses ran and all returned `SAW-STATUS: OK`), or `RECOMMEND_SPLIT_OR_CLEANUP` (any `SAW-STATUS: SUGGEST`) + copy-pasteable `file:line` comments.
