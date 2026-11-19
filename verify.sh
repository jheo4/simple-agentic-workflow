#!/usr/bin/env bash
# Layer 1 fast static & installer verification for Simple Agentic Workflow (SAW).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
TMP_BASE=$(mktemp -d)
trap 'rm -rf "$TMP_BASE"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "[1/6] Checking install.sh syntax..."
bash -n "$ROOT/install.sh" || fail "install.sh has syntax errors"
[ -x "$ROOT/install.sh" ] || fail "install.sh is not executable"

echo "[2/6] Checking skill frontmatter & folder names..."
for skill_md in "$ROOT"/skills/saw-*/SKILL.md; do
  dir_name=$(basename "$(dirname "$skill_md")")
  fm_name=$(awk '/^---$/{f++; next} f==1 && $1=="name:"{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_md" | tr -d '\r')
  fm_desc=$(awk '/^---$/{f++; next} f==1 && $1=="description:"{sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_md" | tr -d '\r')
  [ "$fm_name" = "$dir_name" ] || fail "$skill_md: name '$fm_name' != dir '$dir_name'"
  [ -n "$fm_desc" ] || fail "$skill_md: missing description"
  if [[ "$fm_desc" == *\[* || "$fm_desc" == *": "* ]]; then
    if [[ "$fm_desc" == \"*\" ]]; then
      inner=${fm_desc#\"}; inner=${inner%\"}
      [[ "${inner//\\\"/}" != *\"* ]] || fail "$skill_md: unescaped quote inside description"
    elif [[ "$fm_desc" == \'*\' ]]; then
      inner=${fm_desc#\'}; inner=${inner%\'}
      [[ "${inner//\'\'/}" != *\'* ]] || fail "$skill_md: unescaped single quote inside description"
    else
      fail "$skill_md: description with '[' or ': ' must be quoted"
    fi
  fi
done

echo "[3/6] Checking general.md lens references..."
while IFS='|' read -r _ phase lens use _; do
  lens=$(echo "$lens" | xargs)
  phase=$(echo "$phase" | xargs)
  use=$(echo "$use" | xargs)
  [ -z "$lens" ] && continue
  [ "$lens" = "lens" ] && continue
  [[ "$lens" == ---* ]] && continue
  [ "$use" = "off" ] && continue
  [ -f "$ROOT/templates/lenses/$lens.md" ] || fail "general.md references missing lens file: templates/lenses/$lens.md"
done < <(grep '^|' "$ROOT/templates/packs/general.md")
markers=$(for lens in "$ROOT"/templates/lenses/*.md; do head -n 1 "$lens"; done | sort -u)
[ "$(wc -l <<<"$markers" | tr -d ' ')" -eq 1 ] || fail "templates/lenses/*.md must share one saw-owned first line"
[[ "$markers" == "<!-- saw-owned"* ]] || fail "templates/lenses/*.md first line must start with <!-- saw-owned"
web_lenses=$(awk -F'|' '$5 ~ /^ *yes *$/ { gsub(/ /, "", $3); print $3 }' "$ROOT/templates/packs/general.md" | sort | xargs)
[ "$web_lenses" = "clarity critic diagnostician reality" ] || fail "general.md web: yes rows must be exactly reality, clarity, critic, diagnostician (got: $web_lenses)"
for agent in "$ROOT"/adapters/claude/agents/saw-goldfish*.md "$ROOT"/adapters/copilot/agents/saw-goldfish*.agent.md "$ROOT"/adapters/antigravity/plugin/agents/saw-goldfish*.md; do
  grep -qF '(unverified: external)' "$agent" || fail "$agent: missing (unverified: external) marker rule"
  case "$agent" in
    *-web*)
      grep -qF '`WEB-BLOCKED: <reason>` on its own line' "$agent" || fail "$agent: missing WEB-BLOCKED own-line rule"
      grep -qF 'never paste repo code' "$agent" || fail "$agent: missing web query scrubbing rule"
      ;;
  esac
done

echo "[4/6] Testing install.sh across targets & --update preservation..."
for target in all copilot claude antigravity; do
  proj="$TMP_BASE/proj-$target"
  mkdir -p "$proj"
  "$ROOT/install.sh" "$proj" --targets "$target" >/dev/null
  [ -f "$proj/.saw/protocol.md" ] || fail "$target: missing .saw/protocol.md"
  [ -f "$proj/.saw/packs/general.md" ] || fail "$target: missing .saw/packs/general.md"
  [ -f "$proj/.saw/profile.md" ] || fail "$target: missing .saw/profile.md"
  grep -qxF ".saw/work/" "$proj/.gitignore" || fail "$target: missing .saw/work/ in .gitignore"
done

# Verify UPDATE=0 leaves retired and custom skills untouched without false conflicts
upd="$TMP_BASE/proj-all"
for skill_root in "$upd/.github/skills" "$upd/.claude/skills" "$upd/.agents/skills"; do
  mkdir -p "$skill_root/saw-commit-diff" "$skill_root/saw-diff" "$skill_root/saw-custom" "$skill_root/my-skill"
  touch "$skill_root/saw-commit-diff/SKILL.md" "$skill_root/saw-diff/SKILL.md" "$skill_root/saw-custom/SKILL.md" "$skill_root/my-skill/SKILL.md"
done
out_no_upd=$("$ROOT/install.sh" "$upd")
! echo "$out_no_upd" | grep -q '^skipped ' || fail "UPDATE=0 flagged retired/custom skills as skipped"
for skill_root in "$upd/.github/skills" "$upd/.claude/skills" "$upd/.agents/skills"; do
  [ -d "$skill_root/saw-commit-diff" ] || fail "UPDATE=0 deleted retired saw-commit-diff"
  [ -d "$skill_root/saw-diff" ] || fail "UPDATE=0 deleted retired saw-diff"
  [ -d "$skill_root/saw-custom" ] || fail "UPDATE=0 deleted custom saw-custom"
  [ -d "$skill_root/my-skill" ] || fail "UPDATE=0 deleted custom my-skill"
done

# Verify --update preserves custom .saw/profile.md & custom skills, prunes retired skills, and avoids duplicate markers
echo "custom-marker-line" >> "$upd/.saw/profile.md"
out_upd=$("$ROOT/install.sh" "$upd" --update)
echo "$out_upd" | grep -q 'removed (obsolete):' || fail "--update did not report removed (obsolete)"
grep -qxF "custom-marker-line" "$upd/.saw/profile.md" || fail "--update overwrote .saw/profile.md"
for skill_root in "$upd/.github/skills" "$upd/.claude/skills" "$upd/.agents/skills"; do
  [ ! -e "$skill_root/saw-commit-diff" ] || fail "--update did not prune saw-commit-diff in $skill_root"
  [ ! -e "$skill_root/saw-diff" ] || fail "--update did not prune saw-diff in $skill_root"
  [ -f "$skill_root/saw-custom/SKILL.md" ] || fail "--update removed custom saw-custom in $skill_root"
  [ -f "$skill_root/my-skill/SKILL.md" ] || fail "--update removed custom my-skill in $skill_root"
done

for marker_file in "$upd/.github/copilot-instructions.md" "$upd/CLAUDE.md" "$upd/AGENTS.md"; do
  count=$(grep -c '^<!-- SAW:BEGIN -->$' "$marker_file")
  [ "$count" -eq 1 ] || fail "$marker_file: expected 1 SAW:BEGIN marker, found $count"
done

# Verify reversed SAW markers fail fast without mutating user content
bad_proj="$TMP_BASE/bad-markers"
mkdir -p "$bad_proj"
printf '%s\n' '<!-- SAW:END -->' '<!-- SAW:BEGIN -->' 'user-keep' > "$bad_proj/AGENTS.md"
! "$ROOT/install.sh" "$bad_proj" --targets antigravity --update 2>/dev/null || fail "reversed SAW markers should fail"
grep -qxF "user-keep" "$bad_proj/AGENTS.md" || fail "reversed marker failure mutated AGENTS.md"

echo "[5/6] Testing self-install (dogfooding) into a copied SAW root..."
self_saw="$TMP_BASE/self-saw"
mkdir -p "$self_saw"
cp -R "$ROOT/install.sh" "$ROOT/templates" "$ROOT/skills" "$ROOT/adapters" "$self_saw/"
"$self_saw/install.sh" "$self_saw" >/dev/null
[ -f "$self_saw/.saw/protocol.md" ] || fail "self-install: missing .saw/protocol.md"
for skill_md in "$ROOT"/skills/saw-*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  [ -f "$self_saw/.github/skills/$sname/SKILL.md" ] || fail "self-install: missing .github/skills/$sname/SKILL.md"
  [ -f "$self_saw/.claude/skills/$sname/SKILL.md" ] || fail "self-install: missing .claude/skills/$sname/SKILL.md"
  [ -f "$self_saw/.agents/skills/$sname/SKILL.md" ] || fail "self-install: missing .agents/skills/$sname/SKILL.md"
done
cmp -s "$ROOT/templates/protocol.md" "$self_saw/templates/protocol.md" || fail "self-install mutated source templates/"
echo "self-custom-profile" >> "$self_saw/.saw/profile.md"
"$self_saw/install.sh" "$self_saw" --update >/dev/null
grep -qxF "self-custom-profile" "$self_saw/.saw/profile.md" || fail "self-install --update overwrote .saw/profile.md"

# Lens ownership: custom (marker-less) vs marker-owned vs pre-marker built-in
lens_src="$self_saw/templates/lenses"
lens_dst="$self_saw/.saw/lenses"
for new_lens in zz-new zz-owned; do
  { head -n 1 "$lens_src/critic.md"; echo "# Lens: $new_lens"; } > "$lens_src/$new_lens.md"
done
echo "# My own zz-new lens" > "$lens_dst/zz-new.md"
cp "$lens_dst/zz-new.md" "$TMP_BASE/zz-new.expected"
{ cat "$lens_src/zz-owned.md"; echo "local edit"; } > "$lens_dst/zz-owned.md"
{ tail -n +2 "$lens_src/critic.md"; echo "local edit"; } > "$lens_dst/critic.md"
check_custom_lens() {
  cmp -s "$TMP_BASE/zz-new.expected" "$lens_dst/zz-new.md" || fail "$1: custom zz-new.md was overwritten"
  [ "$(grep -c 'zz-new' <<<"$2")" -eq 1 ] || fail "$1: zz-new.md should be reported exactly once"
  grep 'zz-new' <<<"$2" | grep -qF '(custom lens' || fail "$1: zz-new.md not reported as custom lens"
}
out_lens=$("$self_saw/install.sh" "$self_saw")
check_custom_lens "no --update" "$out_lens"
grep 'zz-owned' <<<"$out_lens" | grep -qvF '(custom lens' || fail "no --update: marker-owned zz-owned.md should be a normal conflict"
grep -qxF "local edit" "$lens_dst/zz-owned.md" || fail "no --update: overwrote marker-owned zz-owned.md"
out_lens=$("$self_saw/install.sh" "$self_saw" --update)
check_custom_lens "--update" "$out_lens"
cmp -s "$lens_src/zz-owned.md" "$lens_dst/zz-owned.md" || fail "--update did not refresh marker-owned zz-owned.md"
cmp -s "$lens_src/critic.md" "$lens_dst/critic.md" || fail "--update did not refresh pre-marker critic.md"

echo "[6/6] Testing canary runner & sandbox builder..."
canary="$ROOT/probes/canary.sh"
prep="$ROOT/probes/prepare-sandbox.sh"
bash -n "$canary" || fail "canary.sh has syntax errors"
[ -x "$canary" ] || fail "probes/canary.sh is not executable"
"$canary" --self-test >/dev/null || fail "canary.sh --self-test failed"
set +e
"$canary" foo </dev/null >/dev/null 2>&1; [ $? -eq 2 ] || fail "canary.sh should reject unknown harness with exit 2"
"$canary" claude P9 </dev/null >/dev/null 2>&1; [ $? -eq 2 ] || fail "canary.sh should reject unknown probe with exit 2"
"$prep" "$HOME" --check-dest >/dev/null 2>&1; [ $? -eq 2 ] || fail "prepare-sandbox.sh should refuse \$HOME"
"$prep" "$ROOT/does-not-exist" --check-dest >/dev/null 2>&1; [ $? -eq 2 ] || fail "prepare-sandbox.sh should refuse a path inside the SAW repo"
not_sandbox="$TMP_BASE/not-sandbox"
mkdir -p "$not_sandbox" && git -C "$not_sandbox" init -q && echo keep >"$not_sandbox/keep.txt"
"$prep" "$not_sandbox" --check-dest >/dev/null 2>&1; [ $? -eq 2 ] || fail "prepare-sandbox.sh should refuse a non-sandbox git repo"
set -e
[ -f "$not_sandbox/keep.txt" ] || fail "prepare-sandbox.sh touched a non-sandbox git repo"
[ ! -e "$ROOT/does-not-exist" ] || fail "prepare-sandbox.sh created a path inside the SAW repo"
sandbox="$TMP_BASE/canary"
"$prep" "$sandbox" >/dev/null
for ref in refs/tags/canary-baseline refs/tags/canary-configured refs/heads/canary/clean-fix refs/heads/canary/ai-grenade; do
  git -C "$sandbox" rev-parse -q --verify "$ref" >/dev/null || fail "sandbox missing $ref"
done
[ "$(git -C "$sandbox" branch --show-current)" = "main" ] || fail "sandbox should be on main"
[ "$(git -C "$sandbox" rev-parse main)" = "$(git -C "$sandbox" rev-parse canary-baseline)" ] || fail "sandbox main should be at canary-baseline"
configured=$(git -C "$sandbox" show canary-configured:.saw/profile.md)
grep -qx 'status: configured' <<<"$configured" || fail "canary-configured profile is not configured"
grep -qx 'test: python3 -m unittest' <<<"$configured" || fail "canary-configured profile lacks test command"
! grep -v '^#' <<<"$configured" | grep -qE '<[^>]+>' || fail "canary-configured profile has template placeholders"
grep -qF -- '- README.md:' <<<"$configured" || fail "canary-configured profile lacks a README.md doc pointer"
[ "$(grep -oE '^[a-z-]+:' <<<"$configured" | sort)" = "$(grep -oE '^[a-z-]+:' "$ROOT/templates/profile.md" | sort)" ] \
  || fail "canary-configured profile keys differ from templates/profile.md"
[ "$(git -C "$sandbox" diff --numstat main canary/clean-fix -- pricing.py)" = "$(printf '1\t1\tpricing.py')" ] \
  || fail "canary/clean-fix should change exactly one line of pricing.py"
"$prep" "$sandbox" --check-dest || fail "prepare-sandbox.sh should accept an existing canary sandbox"

echo "PASS: All Layer 1 SAW checks passed."
