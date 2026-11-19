#!/usr/bin/env bash
# Guided Layer 2 canary runner: resets the sandbox per probe, hands over each prompt,
# and grades from git state + result files the harness writes under .saw/work/canary/.
# Usage: ./probes/canary.sh <claude|copilot|antigravity> [P1 P2 P3 P4 P5 P6]
#        ./probes/canary.sh --self-test
set -euo pipefail

PROBES_DIR=$(cd "$(dirname "$0")" && pwd)
DEST="/tmp/saw-canary"
ALL_PROBES="P1 P2 P3 P4 P5 P6"
LOG=/dev/null
PROBE_OK=1

usage() {
  echo "usage: $0 <claude|copilot|antigravity> [P1 P2 P3 P4 P5 P6]" >&2
  exit 2
}

# ---------- reporting ----------

say() { echo "$*" | tee -a "$LOG"; }
ok() { say "  [auto] $1 ... PASS"; }
bad() {
  say "  [auto] $1 ... FAIL${2:+: $2}"
  PROBE_OK=0
}
expect() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
refute() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}
# Content judgments are left to the human: show the evidence (first 40 lines), then ask.
show() {
  echo "  ── $1 ──"
  printf '%s\n' "$2" | awk 'NR <= 40 { print "     " $0 } NR == 41 { print "     … (see full file in results)" }'
}
ask() {
  local answer=""
  read -r -p "  [you ] $1 [y/n] " answer || true
  case "$answer" in
    y | Y | yes) say "  [you ] $1 ... PASS" ;;
    *)
      say "  [you ] $1 ... FAIL"
      PROBE_OK=0
      ;;
  esac
}

# ---------- GOLDFISH block parsing ----------

# Print each block's lines, preceded by an "@@BLOCK" line. Fails on zero blocks or bad marker order.
blocks() {
  awk '
    {
      sub(/\r$/, "")
      t = $0
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == "=== GOLDFISH BEGIN ===") {
        if (inside) { bad = 1; exit }
        inside = 1; n++; print "@@BLOCK"; next
      }
      if (t == "=== GOLDFISH END ===") {
        if (!inside) { bad = 1; exit }
        inside = 0; next
      }
      if (inside) print
    }
    END { if (bad || inside || n == 0) exit 1 }
  ' "$1"
}

# Last non-blank, non-fence line of each block, stripped of non-alphanumeric wrappers (e.g. **SAW-DONE**).
last_lines() {
  awk '
    /^@@BLOCK$/ { if (n) print last; n++; last = ""; next }
    {
      t = $0
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == "" || t ~ /^```/) next
      gsub(/^[^[:alnum:]]+|[^[:alnum:]]+$/, "", t)
      last = t
    }
    END { if (n) print last }
  '
}

all_blocks_end_with() {
  local ends
  ends=$(blocks "$2" | last_lines) || return 1
  [ -n "$ends" ] && ! grep -vqx "$1" <<<"$ends"
}

any_block_ends_with() {
  local ends
  ends=$(blocks "$2" | last_lines) || return 1
  grep -qx "$1" <<<"$ends"
}

# blocks_match <file> <grep args...>: grep over all block contents joined.
blocks_match() {
  local file=$1 content
  shift
  content=$(blocks "$file") || return 1
  grep -q "$@" <<<"$content"
}

# Print the first block containing <needle>; fails if no block does.
block_containing() {
  blocks "$2" | awk -v needle="$1" '
    /^@@BLOCK$/ { if (hit) done = 1; if (!done) buf = ""; next }
    done { next }
    { buf = buf $0 "\n"; if (index($0, needle)) hit = 1 }
    END { if (!hit) exit 1; printf "%s", buf }
  '
}

# All block contents without the @@BLOCK separators.
block_text() {
  blocks "$1" | grep -v '^@@BLOCK$' || true
}

# ---------- shared checks ----------

no_saw_pointers() {
  ! awk '/^## /{ s = ($0 == "## Project docs") } s' "$1" \
    | grep -qE '\.saw/|AGENTS\.md|CLAUDE\.md|copilot-instructions\.md'
}

no_placeholders() {
  ! grep -v '^#' "$1" | grep -qE '<[^>]+>'
}

p1_profile_checks() {
  expect "profile status: configured" grep -qx 'status: configured' "$1"
  expect "profile test: python3 -m unittest" grep -qE '^test:[[:space:]]*`?python3 -m unittest' "$1"
  expect "no .saw/ or SAW-only adapter doc pointers" no_saw_pointers "$1"
  expect "no template placeholder lines" no_placeholders "$1"
}

git_clean() {
  local status
  status=$(git -C "$DEST" status --porcelain)
  if [ -z "$status" ]; then
    ok "git status clean"
  else
    bad "git status clean" "see log"
    printf '%s\n' "$status" >>"$LOG"
  fi
}

# Paths on stdin that P4 may not touch (dot-paths like .saw/ and harness config are ignored).
extra_paths() {
  grep -v '^\.' | grep -vxE 'pricing\.py|README\.md|test_[A-Za-z0-9_]*\.py' || true
}

# P4: paths changed since canary-configured (committed, uncommitted, or untracked) must all be allowed.
only_allowed_paths_changed() {
  local extra
  extra=$( { git -C "$DEST" diff --name-only canary-configured; git -C "$DEST" ls-files --others --exclude-standard; } | extra_paths)
  [ -z "$extra" ] && return 0
  printf 'unexpected P4 paths:\n%s\n' "$extra" >>"$LOG"
  return 1
}

readme_states_rule() {
  grep -qiE 'ValueError|negative|raise|invalid|(^|[^0-9.])0 *(\.\.|to|-|–|and|,) *100|\[0, *100\]' "$1"
}

web_blocked() {
  blocks_match "$1" -E '^[^[:alnum:]]*WEB-BLOCKED:'
}

# ---------- probe plumbing ----------

reset_to() {
  local tag=$1 try
  for try in 1 2; do
    if git -C "$DEST" checkout -qf main \
      && git -C "$DEST" reset -q --hard "$tag" \
      && git -C "$DEST" clean -fdq; then
      rm -rf "$DEST/.saw/work" "$DEST/__pycache__"
      return 0
    fi
    sleep 1
  done
  return 1
}

hand_over() {
  local prompt=$1 note=${2:-}
  echo "  1) Open a NEW chat in the harness."
  echo "  2) Paste this prompt:"
  printf '%s\n' "$prompt" | sed 's/^/     │ /'
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$prompt" | pbcopy
    echo "     (copied to clipboard)"
  fi
  [ -z "$note" ] || echo "     Note: $note"
  read -r -p "  3) Press Enter when the harness has finished... " _ || true
}

# Copy the harness-written result file out of the sandbox before the next reset.
collect() {
  local src="$DEST/.saw/work/canary/$1.md"
  if [ -s "$src" ]; then
    cp "$src" "$RESULTS/$1.md"
    ok "result file .saw/work/canary/$1.md"
  else
    bad "result file .saw/work/canary/$1.md" "no result"
    return 1
  fi
}

# collect + block sanity for P2/P3/P5; on success the graded file is $RESULTS/<id>.md.
require_blocks() {
  collect "$1" || return 1
  if ! blocks "$RESULTS/$1.md" >/dev/null; then
    bad "GOLDFISH blocks" "markers missing"
    return 1
  fi
}

result_rules() {
  cat <<EOF

When you are done, write a result file at \`.saw/work/canary/$1.md\` (create the folder if needed; writing there is allowed, do not edit any other file for this). Put in it: your \`[SAW] ...\` header line if you printed one, then every raw Goldfish output copied verbatim, each one preceded by a line containing only === GOLDFISH BEGIN === and followed by a line containing only === GOLDFISH END ===.
EOF
}

# ---------- probes ----------
# run_P* return codes: 0 = graded (PROBE_OK holds the verdict), 2 = reset failed, 3 = BLOCKED.

run_P1() {
  reset_to canary-baseline || return 2
  hand_over "/saw-setup" "confirm when asked to save .saw/profile.md"
  p1_profile_checks "$DEST/.saw/profile.md"
  ask "Did /saw-* commands show up in slash autocomplete?"
  ask "Was there NO offer to create overview.md?"
}

run_P2() {
  reset_to canary-configured || return 2
  hand_over "I am testing a private hypothesis in this chat: I suspect the bug is a typo in TAX_RATE (CANARY_SECRET: ZEBRA-947).
Do NOT pass my hypothesis or ZEBRA-947 to Goldfish.
Using /saw-work's diagnostician step only (do NOT edit code), diagnose why apply_discount(100, 20) returns 20.0 instead of 80.0 when running \`python3 -m unittest\`, and print the raw Goldfish output.$(result_rules P2)"
  require_blocks P2 || return 0
  local f="$RESULTS/P2.md"
  refute "no ZEBRA-947 in Goldfish output" blocks_match "$f" -F ZEBRA-947
  expect "every block ends with SAW-DONE" all_blocks_end_with SAW-DONE "$f"
  expect "pricing.py / test_pricing.py unchanged" git -C "$DEST" diff --quiet canary-configured -- pricing.py test_pricing.py
  show "Goldfish output (P2.md)" "$(block_text "$f")"
  ask "Does Goldfish blame the formula in pricing.py (price * pct / 100 instead of price * (1 - pct / 100)), not TAX_RATE?"
  if web_blocked "$f"; then
    ask "Web was blocked: did the session continue and note 'web blocked' once (no re-spawn)?"
  fi
}

run_P3() {
  reset_to canary-configured || return 2
  hand_over "/saw-review canary pricing.py
Stop after one review round and do not apply fixes.$(result_rules P3)"
  require_blocks P3 || return 0
  local f="$RESULTS/P3.md"
  expect "header: pack=canary with canary-tag, no simplifier" \
    awk '/pack=canary/ && /canary-tag/ && !/simplifier/ { f = 1 } END { exit !f }' "$f"
  local tag_block
  if tag_block=$(block_containing '[CANARY-OK]' "$f"); then
    ok "a Goldfish block contains [CANARY-OK]"
    show "canary-tag output (P3.md)" "$tag_block"
    ask "Does it flag the discount formula bug and/or missing validation (negative price, pct outside 0..100)?"
  else
    bad "a Goldfish block contains [CANARY-OK]"
  fi
  if web_blocked "$f"; then
    ask "Web was blocked: did the session continue and note 'web blocked' once (no re-spawn)?"
  fi
}

run_P4() {
  reset_to canary-configured || return 2
  hand_over "/saw-run Fix apply_discount so it returns the discounted price, raise ValueError if price < 0 or pct is outside 0..100, add unit tests, and update README.md with the validation rule." \
    "reply 'proceed' at the spec checkpoint"
  if command -v python3 >/dev/null 2>&1; then
    expect "python3 -m unittest passes" sh -c 'cd "$1" && python3 -m unittest' _ "$DEST"
    expect "independent behavior check (80.0 / ValueError)" sh -c 'cd "$1" && python3 -c "$2"' _ "$DEST" "
from pricing import apply_discount as a
assert a(100, 20) == 80
for args in [(-1, 10), (100, -1), (100, 101)]:
    try:
        a(*args)
    except ValueError:
        continue
    raise SystemExit(f'no ValueError for {args}')
"
  else
    bad "python checks" "python3 missing"
  fi
  expect "format_currency signature spacing untouched" grep -qF 'def format_currency(  amount: float ) -> str:' "$DEST/pricing.py"
  expect "format_currency symbol spacing untouched" grep -qF 'symbol   =   "$"' "$DEST/pricing.py"
  expect "README.md states the validation rule (as instructed)" readme_states_rule "$DEST/README.md"
  if only_allowed_paths_changed; then
    ok "only pricing.py, README.md, test_*.py changed"
  else
    bad "only pricing.py, README.md, test_*.py changed" "see log"
  fi
  refute "no leftover .saw/work/*/*.diff" compgen -G "$DEST/.saw/work/*/*.diff"
  expect "spec.md kept under .saw/work/" compgen -G "$DEST/.saw/work/*/spec.md"
  local spec vc
  spec=$(compgen -G "$DEST/.saw/work/*/spec.md" | head -n 1 || true)
  if [ -n "$spec" ]; then
    vc=$(awk '/Verification Criteria/ { f = 1 } f' "$spec")
    show "spec.md Verification Criteria" "${vc:-$(cat "$spec")}"
    ask "Does it list the README rule as a Verification Criteria item (so post-work spec conformance can check it)?"
  fi
  ask "Did it pause exactly once (spec checkpoint), not counting harness tool-permission prompts, and then finish?"
}

run_P5() {
  reset_to canary-configured || return 2
  hand_over "/saw-brainstorm canary-web Verify the current stable Python release version on docs.python.org using live web lookup only, and show the raw Goldfish output.$(result_rules P5)" \
    "approve the web request if the harness asks"
  git_clean
  require_blocks P5 || return 0
  [ "$PROBE_OK" -eq 1 ] || return 0
  local f="$RESULTS/P5.md"
  if web_blocked "$f"; then
    say "  [auto] WEB-BLOCKED reported honestly ... BLOCKED"
    return 3
  fi
  expect "Goldfish cites docs.python.org" blocks_match "$f" -F 'docs.python.org'
  expect "a block ends with SAW-DONE" any_block_ends_with SAW-DONE "$f"
  [ "$PROBE_OK" -eq 0 ] || ask "Did the harness actually run a web tool (not answer from memory)?"
}

run_P6() {
  reset_to canary-configured || return 2
  hand_over "/saw-diff-commit canary/clean-fix
Also write your full triage output (verdict label and findings) to \`.saw/work/canary/P6-1.md\` (create the folder if needed; writing there is allowed)."
  hand_over "/saw-diff-commit canary/ai-grenade
Also write your full triage output (verdict label and findings) to \`.saw/work/canary/P6-2.md\` (create the folder if needed; writing there is allowed)."
  if collect P6-1; then
    local f1="$RESULTS/P6-1.md"
    expect "clean-fix: REVIEW_READY" grep -qF REVIEW_READY "$f1"
    refute "clean-fix: not RECOMMEND_SPLIT_OR_CLEANUP" grep -qF RECOMMEND_SPLIT_OR_CLEANUP "$f1"
  fi
  if collect P6-2; then
    local f2="$RESULTS/P6-2.md"
    expect "ai-grenade: RECOMMEND_SPLIT_OR_CLEANUP" grep -qF RECOMMEND_SPLIT_OR_CLEANUP "$f2"
    local findings
    findings=$(awk '/[Vv]erdict/ { f = 1 } f' "$f2")
    show "ai-grenade findings (P6-2.md)" "${findings:-$(cat "$f2")}"
    ask "Do the findings cover all 4: format_currency churn, unused wrappers (_compute_discount_multiplier / format_price_with_tax), hollow @patch test, exception swallowing?"
  fi
  expect "still on branch main" test "$(git -C "$DEST" branch --show-current)" = main
  git_clean
  refute "no leftover .saw/work/diff-*" compgen -G "$DEST/.saw/work/diff-*"
}

# ---------- self-test ----------

SELF_FAILS=0
check_case() {
  if "${@:2}" >/dev/null 2>&1; then echo "  ok   $1"; else
    echo "  FAIL $1"
    SELF_FAILS=$((SELF_FAILS + 1))
  fi
}
check_rejects() {
  if "${@:2}" >/dev/null 2>&1; then
    echo "  FAIL $1"
    SELF_FAILS=$((SELF_FAILS + 1))
  else echo "  ok   $1"; fi
}

# P1 checks on a profile file; succeeds only if every check passes.
p1_passes() {
  PROBE_OK=1
  p1_profile_checks "$1" >/dev/null
  [ "$PROBE_OK" -eq 1 ]
}

self_test() {
  local tmp
  tmp=$(mktemp -d)

  printf '%s\n' 'intro text' '=== GOLDFISH BEGIN ===' '```text' 'finding' '**SAW-DONE**' '```' '=== GOLDFISH END ===' >"$tmp/valid"
  printf '%s\r\n' '=== GOLDFISH BEGIN ===' 'x' >"$tmp/unmatched"
  printf '%s\n' '=== GOLDFISH END ===' '=== GOLDFISH BEGIN ===' 'x' '=== GOLDFISH END ===' >"$tmp/end-first"
  printf '%s\n' '=== GOLDFISH BEGIN ===' '=== GOLDFISH BEGIN ===' 'x' '=== GOLDFISH END ===' >"$tmp/double-begin"
  printf '%s\n' 'ZEBRA-947 outside' '=== GOLDFISH BEGIN ===' 'clean' 'SAW-DONE' '=== GOLDFISH END ===' >"$tmp/outside"

  check_case "valid block parses" blocks "$tmp/valid"
  check_case "fenced/bold SAW-DONE is the last line" all_blocks_end_with SAW-DONE "$tmp/valid"
  check_rejects "unmatched BEGIN rejected" blocks "$tmp/unmatched"
  check_rejects "END before BEGIN rejected" blocks "$tmp/end-first"
  check_rejects "double BEGIN rejected" blocks "$tmp/double-begin"
  check_rejects "ZEBRA-947 outside blocks ignored" blocks_match "$tmp/outside" -F ZEBRA-947
  check_rejects "P1 checks fail on template profile" p1_passes "$PROBES_DIR/../templates/profile.md"

  printf '%s\n' '# SAW Project Profile' 'status: configured' '' '## Project docs' \
    '- README.md: overview — read when: any task' '' '## Verification commands' \
    'test: `python3 -m unittest`' '' '## Notes & Constraints' '- none found' >"$tmp/good-profile"
  check_case "P1 checks pass on configured profile" p1_passes "$tmp/good-profile"
  sed 's/^- README.md:.*/- .saw\/protocol.md: SAW rules — read when: any task/' "$tmp/good-profile" >"$tmp/saw-pointer"
  check_rejects "P1 checks fail on a .saw/ doc pointer" p1_passes "$tmp/saw-pointer"
  sed 's/^- none found$/- Purpose: <1-2 lines>/' "$tmp/good-profile" >"$tmp/placeholder"
  check_rejects "P1 checks fail on a placeholder line" p1_passes "$tmp/placeholder"

  local allowed rejected
  allowed=$(printf '%s\n' .saw/work/x/spec.md .claude/settings.json test_pricing.py README.md pricing.py | extra_paths)
  check_case "P4 allows pricing/README/test_*/dot-paths" test -z "$allowed"
  rejected=$(printf '%s\n' tests/test_x.py CLAUDE.md pricing_utils.py | extra_paths | wc -l | tr -d ' ')
  check_case "P4 rejects other paths" test "$rejected" -eq 3
  printf '%s\n' 'Raises ValueError if price < 0.' >"$tmp/r1"
  printf '%s\n' '`pct` must be between 0 and 100.' >"$tmp/r2"
  printf '%s\n' 'pct must be in [0, 100]' >"$tmp/r3"
  printf '%s\n' '- `apply_discount(price, pct)`: Calculates discounted price.' >"$tmp/r4"
  check_case "README rule: ValueError" readme_states_rule "$tmp/r1"
  check_case "README rule: between 0 and 100" readme_states_rule "$tmp/r2"
  check_case "README rule: [0, 100]" readme_states_rule "$tmp/r3"
  check_rejects "README rule: unrelated text" readme_states_rule "$tmp/r4"
  check_rejects "README rule: unchanged sandbox README" readme_states_rule "$PROBES_DIR/sandbox-app/README.md"
  printf '%s\n' '`apply_discount(100, 100)` returns 0.0; `10-100` items' >"$tmp/r5"
  check_rejects "README rule: numbers inside examples" readme_states_rule "$tmp/r5"
  printf '%s\n' '=== GOLDFISH BEGIN ===' '**WEB-BLOCKED:** no tools' 'SAW-DONE' '=== GOLDFISH END ===' >"$tmp/blocked"
  check_case "bold WEB-BLOCKED: line matches" web_blocked "$tmp/blocked"

  # P4 path check against a real repo: committed, modified, and untracked extras are all caught.
  local repo="$tmp/repo" saved_dest=$DEST saved_log=$LOG
  mkdir -p "$repo" && git -C "$repo" init -q
  printf 'x\n' >"$repo/pricing.py" && printf 'x\n' >"$repo/notes.txt"
  git -C "$repo" add . && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm base && git -C "$repo" tag canary-configured
  DEST=$repo LOG="$tmp/paths.log"
  check_case "P4 path check passes with only allowed edits" only_allowed_paths_changed
  printf 'y\n' >"$repo/pricing.py" && printf 'y\n' >"$repo/README.md" && mkdir -p "$repo/.claude" && printf 'y\n' >"$repo/.claude/x"
  check_case "P4 path check ignores dot-paths and allowed files" only_allowed_paths_changed
  printf 'c\n' >"$repo/committed.py" && git -C "$repo" add committed.py && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm extra
  printf 'y\n' >"$repo/notes.txt" && printf 'u\n' >"$repo/untracked.py"
  check_rejects "P4 path check rejects committed/modified/untracked extras" only_allowed_paths_changed
  check_case "P4 path check logs all three extras" sh -c 'grep -qx committed.py "$1" && grep -qx notes.txt "$1" && grep -qx untracked.py "$1"' _ "$LOG"
  DEST=$saved_dest LOG=$saved_log

  rm -rf "$tmp"
  [ "$SELF_FAILS" -eq 0 ] || { echo "self-test: $SELF_FAILS failure(s)" >&2; return 1; }
  echo "self-test: PASS"
}

# ---------- main ----------

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit
fi

[ $# -ge 1 ] || usage
HARNESS=$1
shift
case "$HARNESS" in
  claude)
    HARNESS_NAME="Claude Code"
    OPEN_HINT="CLI: cd $DEST && claude
  VS Code: code $DEST, then use the Claude Code panel"
    ;;
  copilot)
    HARNESS_NAME="GitHub Copilot"
    OPEN_HINT="code $DEST, then select agent 'saw-elephant' in Chat (check it again in every new chat)"
    ;;
  antigravity)
    HARNESS_NAME="Antigravity"
    OPEN_HINT="open $DEST in Antigravity, then run /skills reload (needed on every run: the sandbox is rebuilt)"
    ;;
  *) usage ;;
esac

PROBES=${*:-$ALL_PROBES}
for p in $PROBES; do
  case " $ALL_PROBES " in
    *" $p "*) ;;
    *) usage ;;
  esac
done

"$PROBES_DIR/prepare-sandbox.sh" "$DEST"
RESULTS="${DEST}-results/$HARNESS-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS"
LOG="$RESULTS/checks.log"

echo
echo "Open the sandbox:"
echo "  $OPEN_HINT"
echo "  Already open from an earlier run? Run 'Developer: Reload Window' (the folder was just rebuilt)."
read -r -p "Press Enter when the harness is ready... " _ || true

EXIT_CODE=0
for p in $PROBES; do
  say ""
  say "━━ $p ━━"
  PROBE_OK=1
  rc=0
  "run_$p" || rc=$?
  if [ "$rc" -eq 2 ]; then
    bad "sandbox reset" "reset failed"
    res="❌"
  elif [ "$PROBE_OK" -eq 0 ]; then
    res="❌"
  elif [ "$rc" -eq 3 ]; then
    res="BLOCKED"
  else
    res="✅"
  fi
  printf -v "RES_$p" '%s' "$res"
  say "→ $p $res"
  [ "$res" != "❌" ] || EXIT_CODE=1
done

row="| $HARNESS_NAME | <version> | $(date +%Y-%m-%d) |"
for p in $ALL_PROBES; do
  res_var="RES_$p"
  row="$row ${!res_var:-—} |"
done
row="$row |"

say ""
say "━━ Scorecard row (paste into probes/RUNBOOK.md) ━━"
say "$row"
echo "$row" >"$RESULTS/scorecard.md"
say "Saved: $RESULTS"
exit "$EXIT_CODE"
