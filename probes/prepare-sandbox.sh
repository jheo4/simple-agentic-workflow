#!/usr/bin/env bash
# Prepare a clean disposable git sandbox for Layer 2 SAW harness canary probes.
# Usage: ./probes/prepare-sandbox.sh [dest-dir] [--targets all|copilot,claude,antigravity]
set -euo pipefail

DEST="/tmp/saw-canary"
TARGETS="all"

if [ $# -ge 1 ] && [[ "$1" != --* ]]; then
  DEST=$1
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --targets)
      [ $# -ge 2 ] || { echo "error: --targets requires a value" >&2; exit 2; }
      TARGETS=$2
      shift 2
      ;;
    --targets=*)
      TARGETS=${1#--targets=}
      shift
      ;;
    *)
      echo "usage: $0 [dest-dir] [--targets all|copilot,claude,antigravity]" >&2
      exit 2
      ;;
  esac
done

PROBES_DIR=$(cd "$(dirname "$0")" && pwd)
SAW_ROOT=$(cd "$PROBES_DIR/.." && pwd)

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$PROBES_DIR/sandbox-app/." "$DEST/"

"$SAW_ROOT/install.sh" "$DEST" --targets "$TARGETS" >/dev/null

(
  cd "$DEST"
  git init -q
  git checkout -B main >/dev/null 2>&1 || true
  git config user.name "SAW Canary"
  git config user.email "canary@example.invalid"
  git add -A
  git commit -q -m "chore: baseline canary sandbox with SAW installed"
)

echo "Canary sandbox ready at: $DEST (targets: $TARGETS)"
echo "Next: open $DEST in your target harness and follow $PROBES_DIR/RUNBOOK.md"
