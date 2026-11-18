#!/usr/bin/env bash
# Install or update Simple Agentic Workflow (SAW) into any project directory.
#
# Usage:
#   ./install.sh <target-project-dir> [--targets all|copilot,claude,antigravity] [--update]
#
# Target aliases:
#   copilot (or github), claude (or claude-code), antigravity (or agy), all (default)
#
# Ownership:
#   SAW-owned (refreshed on --update; retired saw-* skills pruned on --update):
#     .saw/protocol.md, .saw/packs/general.md, .saw/lenses/*.md carrying the saw-owned marker (plus pre-marker built-ins)
#     Harness skills/agents & <!-- SAW:BEGIN -->...<!-- SAW:END --> blocks
#   Project-owned (never overwritten):
#     .saw/profile.md, custom .saw/packs/*.md, custom .saw/lenses/*.md, custom skills, existing user instructions outside SAW markers

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: install.sh <target-project-dir> [--targets all|copilot,claude,antigravity] [--update]
EOF
  exit 2
}

[ $# -ge 1 ] || usage
TARGET=$1
shift

TARGETS="all"
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --targets)
      [ $# -ge 2 ] || usage
      TARGETS=$2
      shift 2
      ;;
    --targets=*)
      TARGETS=${1#--targets=}
      shift
      ;;
    --update)
      UPDATE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      ;;
  esac
done

[ -d "$TARGET" ] || { echo "error: target directory not found: $TARGET" >&2; exit 1; }

SRC=$(cd "$(dirname "$0")" && pwd)
TARGET=$(cd "$TARGET" && pwd)

use_copilot=0
use_claude=0
use_agy=0

IFS=',' read -r -a raw_targets <<< "$TARGETS"
for t in "${raw_targets[@]}"; do
  case "$t" in
    all) use_copilot=1; use_claude=1; use_agy=1 ;;
    copilot|github) use_copilot=1 ;;
    claude|claude-code) use_claude=1 ;;
    antigravity|agy) use_agy=1 ;;
    *)
      echo "error: invalid target '$t' (expected all, copilot, claude, antigravity)" >&2
      exit 2
      ;;
  esac
done

BEGIN_MARK='<!-- SAW:BEGIN -->'
END_MARK='<!-- SAW:END -->'

installed=()
updated=()
unchanged=()
conflicts=()
kept=()
removed=()

copy_owned() {
  local src_rel=$1 dst_rel=$2
  local src="$SRC/$src_rel" dst="$TARGET/$dst_rel"
  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    installed+=("$dst_rel")
  elif cmp -s "$src" "$dst"; then
    unchanged+=("$dst_rel")
  elif [ "$UPDATE" -eq 1 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    updated+=("$dst_rel")
  else
    conflicts+=("$dst_rel")
  fi
}

install_block() {
  local src_rel=$1 dst_rel=$2
  local src="$SRC/$src_rel" dst="$TARGET/$dst_rel"
  local label="$dst_rel (SAW block)"

  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    installed+=("$label")
    return
  fi

  if grep -qxF "$BEGIN_MARK" "$dst"; then
    local begin_count end_count begin_line end_line
    begin_count=$(grep -cxF "$BEGIN_MARK" "$dst")
    end_count=$(grep -cxF "$END_MARK" "$dst" || true)
    [ "$begin_count" -eq 1 ] && [ "$end_count" -eq 1 ] || {
      echo "error: $dst_rel must contain exactly one $BEGIN_MARK and one $END_MARK; fix it manually" >&2
      exit 1
    }
    begin_line=$(grep -nxF "$BEGIN_MARK" "$dst" | cut -d: -f1)
    end_line=$(grep -nxF "$END_MARK" "$dst" | cut -d: -f1)
    [ "$begin_line" -lt "$end_line" ] || {
      echo "error: $dst_rel has $END_MARK before $BEGIN_MARK; fix it manually" >&2
      exit 1
    }
    local tmp
    tmp=$(mktemp)
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v f="$src" '
      $0==b { while ((getline line < f) > 0) print line; close(f); skip=1; next }
      $0==e { skip=0; next }
      !skip { print }
    ' "$dst" > "$tmp"
    if cmp -s "$tmp" "$dst"; then
      rm -f "$tmp"
      unchanged+=("$label")
    elif [ "$UPDATE" -eq 1 ]; then
      mv "$tmp" "$dst"
      updated+=("$label")
    else
      rm -f "$tmp"
      conflicts+=("$label")
    fi
  else
    {
      if [ -s "$dst" ] && [ -n "$(tail -c1 "$dst")" ]; then
        echo
      fi
      [ -s "$dst" ] && echo
      cat "$src"
    } >> "$dst"
    installed+=("$dst_rel (SAW block appended)")
  fi
}

RETIRED_SKILLS=(saw-commit-diff saw-diff)
# Frozen: lenses shipped before the marker. Never add new lenses here; new lenses rely on the marker.
PRE_MARKER_LENSES=(incremental reframe zoom reality clarity critic simplifier diagnostician concept direction detail)

# An existing lens file is custom (project-owned) if its first line lacks the saw-owned
# marker prefix (stable across marker wording changes) and it is not a pre-marker built-in.
is_custom_lens() {
  local dst=$1 name=$2 old
  [ -e "$dst" ] || return 1
  [[ "$(head -n 1 "$dst" | tr -d '\r')" == "<!-- saw-owned"* ]] && return 1
  for old in "${PRE_MARKER_LENSES[@]}"; do
    [ "$name" = "$old" ] && return 1
  done
  return 0
}

install_skills_into() {
  local prefix=$1
  local skill_dir skill_name old_name old_dir
  for skill_dir in "$SRC"/skills/saw-*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    copy_owned "skills/$skill_name/SKILL.md" "$prefix/skills/$skill_name/SKILL.md"
  done
  if [ "$UPDATE" -eq 1 ]; then
    for old_name in "${RETIRED_SKILLS[@]}"; do
      old_dir="$TARGET/$prefix/skills/$old_name"
      if [ -d "$old_dir" ]; then
        rm -rf "$old_dir"
        removed+=("$prefix/skills/$old_name")
      fi
    done
  fi
}

# 1. Core (.saw/)
copy_owned "templates/protocol.md" ".saw/protocol.md"
copy_owned "templates/packs/general.md" ".saw/packs/general.md"
for lens in "$SRC"/templates/lenses/*.md; do
  [ -f "$lens" ] || continue
  lens_name=$(basename "$lens")
  if is_custom_lens "$TARGET/.saw/lenses/$lens_name" "${lens_name%.md}"; then
    kept+=(".saw/lenses/$lens_name (custom lens; SAW now ships this name — rename yours)")
    continue
  fi
  copy_owned "templates/lenses/$lens_name" ".saw/lenses/$lens_name"
done

# Project-owned profile (only create if absent)
if [ -e "$TARGET/.saw/profile.md" ]; then
  kept+=(".saw/profile.md")
else
  mkdir -p "$TARGET/.saw"
  cp "$SRC/templates/profile.md" "$TARGET/.saw/profile.md"
  installed+=(".saw/profile.md")
fi

# 2. Harness adapters
if [ "$use_copilot" -eq 1 ]; then
  install_block "adapters/copilot/copilot-instructions-block.md" ".github/copilot-instructions.md"
  install_skills_into ".github"
  for agent in "$SRC"/adapters/copilot/agents/*.agent.md; do
    [ -f "$agent" ] || continue
    agent_name=$(basename "$agent")
    copy_owned "adapters/copilot/agents/$agent_name" ".github/agents/$agent_name"
  done
fi

if [ "$use_claude" -eq 1 ]; then
  install_block "adapters/claude/claude-md-block.md" "CLAUDE.md"
  install_skills_into ".claude"
  for agent in "$SRC"/adapters/claude/agents/*.md; do
    [ -f "$agent" ] || continue
    agent_name=$(basename "$agent")
    copy_owned "adapters/claude/agents/$agent_name" ".claude/agents/$agent_name"
  done
fi

if [ "$use_agy" -eq 1 ]; then
  install_block "adapters/antigravity/agents-md-block.md" "AGENTS.md"
  install_skills_into ".agents"
  copy_owned "adapters/antigravity/plugin/plugin.json" ".agents/plugins/saw/plugin.json"
  for agent in "$SRC"/adapters/antigravity/plugin/agents/*.md; do
    [ -f "$agent" ] || continue
    agent_name=$(basename "$agent")
    copy_owned "adapters/antigravity/plugin/agents/$agent_name" ".agents/plugins/saw/agents/$agent_name"
  done
fi

# 3. Ignore ephemeral work directories
GI="$TARGET/.gitignore"
if [ -e "$GI" ] && grep -qxE '/?\.saw/work/?' "$GI"; then
  unchanged+=(".gitignore (.saw/work/)")
else
  {
    if [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ]; then
      echo
    fi
    echo ".saw/work/"
  } >> "$GI"
  installed+=(".gitignore (.saw/work/)")
fi

report() {
  local title=$1
  shift
  [ $# -gt 0 ] || return 0
  echo "$title"
  local item
  for item in "$@"; do
    echo "  $item"
  done
}

echo "SAW install into $TARGET (targets: $TARGETS)"
report "installed:" ${installed[@]+"${installed[@]}"}
report "updated:" ${updated[@]+"${updated[@]}"}
report "removed (obsolete):" ${removed[@]+"${removed[@]}"}
report "unchanged:" ${unchanged[@]+"${unchanged[@]}"}
report "kept (project-owned):" ${kept[@]+"${kept[@]}"}
if [ "${#conflicts[@]}" -gt 0 ]; then
  report "skipped (differs from template; rerun with --update to overwrite):" "${conflicts[@]}"
fi

echo
echo "Next steps:"
echo "  1. Open $TARGET in your coding agent:"
[ "$use_copilot" -eq 1 ] && echo "     - GitHub Copilot: select agent 'saw-elephant' in Chat, then run /saw-setup"
[ "$use_claude" -eq 1 ]  && echo "     - Claude Code: run /saw-setup directly"
[ "$use_agy" -eq 1 ]     && echo "     - Antigravity: run /saw-setup directly"
echo "  2. For a full end-to-end task later, run /saw-run <task>."
