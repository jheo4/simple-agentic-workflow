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

echo "[1/5] Checking install.sh syntax..."
bash -n "$ROOT/install.sh" || fail "install.sh has syntax errors"
[ -x "$ROOT/install.sh" ] || fail "install.sh is not executable"

echo "[2/5] Checking skill frontmatter & folder names..."
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

echo "[3/5] Checking general.md lens references..."
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

echo "[4/5] Testing install.sh across targets & --update preservation..."
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

echo "[5/5] Testing self-install (dogfooding) into a copied SAW root..."
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

echo "PASS: All Layer 1 SAW checks passed."
