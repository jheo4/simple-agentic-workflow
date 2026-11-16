---
name: saw-diff-files
description: "[Diff: Files/Dirs] Read-only comparison of any two files or directories (code, data, or docs) across concept, direction, and detail."
argument-hint: "[pack] <left> <right> [focus]"
disable-model-invocation: true
---
# SAW Diff Files

Read `.saw/protocol.md` first and follow P0–P2 (`phase = diff`, requiring a `.saw/` workspace). Strictly read-only: never modify targets or run `git commit`.

## 1. Parse Arguments & Validate Targets
Resolve `[pack]` before P0 pack inheritance/header: treat `arg1` as `[pack]` only if it has no `/`, matches a `.saw/packs/<name>.md` stem, and either does not exist on disk (`! -e`) or is followed by two existing target paths (`-e "$arg2" && -e "$arg3"`). Prefix `./` (e.g., `./general`) to force path interpretation. Fail fast with usage if `< 2` targets remain, and join trailing tokens after `<right>` as optional user `FOCUS`.

Validate both `"$LEFT"` and `"$RIGHT"` before creating temp files: require regular files (`-f`) or directories (`-d`), rejecting missing paths, broken symlinks (`-L && ! -e`), and special files (FIFOs/sockets/devices).

## 2. Package Comparison (`DIFF_PATH`)
1. During directory traversal, skip `.git`, `node_modules`, `__pycache__`, `*.lock`, `*-lock.*`, `package-lock.json`, binaries, symlinks, and special files—recording unique/differing entries and checking shared binaries/lockfiles via `cmp -s` (treat 0-byte `! -s` files as empty text; allow explicit lockfile single-file pairs).
2. **Short-circuit before `mktemp` and Goldfish**:
   - Identical files (`cmp -s` / `exit 0`) or directories with identical full inventories and zero text/binary/excluded byte differences → report `IDENTICAL_OR_EQUIVALENT` and stop.
   - Binary-only pairs (`cmp -s` differs) or directories with zero differing shared text files and zero unshared text files (only non-text/excluded/binary/symlink entries differ) → report `INVENTORY_DIFF_ONLY` listing differing entries and stop.
3. Otherwise, `mkdir -p .saw/work` and create `DIFF_PATH` via `mktemp .saw/work/diff-XXXXXX` (always delete only `"$DIFF_PATH"` on every exit path, including diff errors). Write up to ~1,500 lines total with an explicit truncation notice:
   - `=== INVENTORY ===`: shared, left-only, right-only, and differing binary/excluded/symlink entries.
   - `=== SHARED DIFFS ===`: `git diff --no-index --no-color --no-ext-diff -U5 --` (prefix `./` on relative `-*` names; exit `0`/`1` valid, `>1` error under `set -e`) per shared same-format text file.
   - `=== EXCERPTS (LEFT / RIGHT) ===`: bounded excerpts for unshared text files, mixed file-vs-dir, or cross-format text files (e.g., `.json` vs `.yaml`).

## 3. Run Active `diff` Lenses
If `lenses=none`, skip Goldfish; otherwise run active `diff` lenses (`concept`, `direction`, `detail`) in parallel passing ONLY `LENS` + pack `FOCUS` + `PROFILE` + `TARGET` (`LEFT`, `RIGHT`, optional user `FOCUS`, and `DIFF_PATH`, instructing Goldfish that `DIFF_PATH` is authoritative and to consult `.saw/profile.md`/repo files only when targets belong to this workspace).

## 4. Report & Clean Up
Delete `"$DIFF_PATH"` and present:
1. **Alignment & Concept (`concept`)**: correspondence map (`LEFT X <-> RIGHT Y`) + macro concept/boundary differences.
2. **Direction & Trade-offs (`direction`)**: approach, structure, and design/narrative trade-offs.
3. **Details, Gaps & Risks (`detail`)**: concrete code/data/doc drift, contradictions, missing items, and exact paths/lines.
4. **Verdict**: `IDENTICAL_OR_EQUIVALENT` (zero semantic/behavioral/data gaps), `INVENTORY_DIFF_ONLY` (short-circuit when only non-text/excluded entries differ), `INTENTIONAL_DIVERGENCE` (substantive conceptual/directional differences without defects), `DRIFT_OR_GAP_FOUND` (`detail` or `concept` flags concrete bugs, contradictions, or unintended drift/gaps), or `SUMMARY_ONLY` (`lenses=none`).
