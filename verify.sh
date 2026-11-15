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

echo "[1/4] Checking install.sh syntax..."
bash -n "$ROOT/install.sh" || fail "install.sh has syntax errors"
[ -x "$ROOT/install.sh" ] || fail "install.sh is not executable"

echo "[2/4] Checking skill frontmatter & folder names..."
for skill_md in "$ROOT"/skills/saw-*/SKILL.md; do
  dir_name=$(basename "$(dirname "$skill_md")")
  fm_name=$(awk -F': *' '$1=="name"{print $2; exit}' "$skill_md" | tr -d '\r')
  fm_desc=$(awk -F': *' '$1=="description"{print $2; exit}' "$skill_md" | tr -d '\r')
  [ "$fm_name" = "$dir_name" ] || fail "$skill_md: name '$fm_name' != dir '$dir_name'"
  [ -n "$fm_desc" ] || fail "$skill_md: missing description"
done

echo "[3/4] Checking general.md lens references..."
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

echo "[4/4] Testing install.sh across targets & --update preservation..."
for target in all copilot claude antigravity; do
  proj="$TMP_BASE/proj-$target"
  mkdir -p "$proj"
  "$ROOT/install.sh" "$proj" --targets "$target" >/dev/null
  [ -f "$proj/.saw/protocol.md" ] || fail "$target: missing .saw/protocol.md"
  [ -f "$proj/.saw/packs/general.md" ] || fail "$target: missing .saw/packs/general.md"
  [ -f "$proj/.saw/profile.md" ] || fail "$target: missing .saw/profile.md"
  grep -qxF ".saw/work/" "$proj/.gitignore" || fail "$target: missing .saw/work/ in .gitignore"
done

# Verify --update preserves custom .saw/profile.md and avoids duplicate markers
upd="$TMP_BASE/proj-all"
echo "custom-marker-line" >> "$upd/.saw/profile.md"
"$ROOT/install.sh" "$upd" --update >/dev/null
grep -qxF "custom-marker-line" "$upd/.saw/profile.md" || fail "--update overwrote .saw/profile.md"

for marker_file in "$upd/.github/copilot-instructions.md" "$upd/CLAUDE.md" "$upd/AGENTS.md"; do
  count=$(grep -c '^<!-- SAW:BEGIN -->$' "$marker_file")
  [ "$count" -eq 1 ] || fail "$marker_file: expected 1 SAW:BEGIN marker, found $count"
done

echo "PASS: All Layer 1 SAW checks passed."
