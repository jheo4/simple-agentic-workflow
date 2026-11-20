#!/usr/bin/env bash
# Prepare a clean disposable git sandbox for Layer 2 SAW harness canary probes.
# Usage: ./probes/prepare-sandbox.sh [dest-dir] [--targets all|copilot,claude,antigravity] [--check-dest]
set -euo pipefail

DEST="/tmp/saw-canary"
TARGETS="all"
CHECK_ONLY=0

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
    --check-dest)
      CHECK_ONLY=1
      shift
      ;;
    *)
      echo "usage: $0 [dest-dir] [--targets all|copilot,claude,antigravity] [--check-dest]" >&2
      exit 2
      ;;
  esac
done

PROBES_DIR=$(cd "$(dirname "$0")" && pwd)
SAW_ROOT=$(cd "$PROBES_DIR/.." && pwd)

refuse() {
  echo "error: refusing to use '$DEST' as a sandbox: $*" >&2
  exit 2
}

# DEST is wiped with rm -rf below, so only accept a new/empty path or an earlier canary sandbox.
check_dest() {
  local parent base abs root
  parent=$(dirname "$DEST")
  base=$(basename "$DEST")
  case "$base" in
    / | . | ..) refuse "not a plain directory name" ;;
  esac
  [ -d "$parent" ] || refuse "parent directory does not exist"
  abs="$(cd "$parent" && pwd -P)/$base"
  root=$(cd "$SAW_ROOT" && pwd -P)
  case "$abs/" in
    "$root"/*) refuse "inside the SAW repo" ;;
  esac
  [ ! -e "$abs" ] || [ -d "$abs" ] || refuse "exists and is not a directory"
  if [ -d "$abs" ] && [ -n "$(ls -A "$abs")" ]; then
    local top
    top=$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null) || top=""
    # Normalize via cd + pwd -P so Windows Git's C:/... output matches MSYS2 POSIX paths.
    [ -n "$top" ] && [ "$(cd "$top" 2>/dev/null && pwd -P)" = "$abs" ] \
      && git -C "$abs" rev-parse -q --verify refs/tags/canary-baseline >/dev/null \
      || refuse "non-empty and not a canary sandbox (if it is an old or half-built sandbox, remove it: rm -rf '$abs')"
  fi
}

check_dest
[ "$CHECK_ONLY" -eq 0 ] || exit 0

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
  git config commit.gpgSign false
  git config tag.gpgSign false
  git add -A
  git commit -q -m "chore: baseline canary sandbox with SAW installed"
  git tag canary-baseline

  # Canary branches for P6 (/saw-diff-commit); main stays unchanged for P1-P5.
  git checkout -q -b canary/clean-fix main
  cat > pricing.py <<'EOF'
"""Minimal sandbox module for SAW canary probes."""

TAX_RATE = 0.08


def apply_discount(price: float, pct: float) -> float:
    """Return final price after applying percentage discount pct (0..100)."""
    return price * (1 - pct / 100)


def format_currency(  amount: float ) -> str:
    symbol   =   "$"
    formatted = f"{symbol}{amount:.2f}"
    return formatted
EOF
  cat > test_pricing.py <<'EOF'
import unittest

from pricing import TAX_RATE, apply_discount, format_currency


class TestPricing(unittest.TestCase):
    def test_tax_rate(self) -> None:
        self.assertEqual(TAX_RATE, 0.08)

    def test_apply_discount_basic(self) -> None:
        self.assertEqual(apply_discount(100, 20), 80.0)
        self.assertEqual(apply_discount(100, 0), 100.0)
        self.assertEqual(apply_discount(100, 100), 0.0)

    def test_format_currency(self) -> None:
        self.assertEqual(format_currency(12.5), "$12.50")


if __name__ == "__main__":
    unittest.main()
EOF
  git add pricing.py test_pricing.py
  git commit -q -m "fix: return remaining price in apply_discount"

  git checkout -q -b canary/ai-grenade main
  cat > pricing.py <<'EOF'
"""Minimal sandbox module for SAW canary probes."""

from typing import Optional

TAX_RATE = 0.08


def _compute_discount_multiplier(pct: float) -> float:
    """Helper to compute the remaining price multiplier from percentage."""
    return 1.0 - (pct / 100.0)


def apply_discount(price: float, pct: float) -> float:
    """Return final price after applying percentage discount pct (0..100)."""
    try:
        multiplier = _compute_discount_multiplier(pct)
        return price * multiplier
    except Exception:
        return 0.0


def format_currency(amount: float) -> str:
    """Format a monetary amount as USD currency string."""
    symbol = "$"
    formatted = f"{symbol}{amount:.2f}"
    return formatted


def format_price_with_tax(amount: float, rate: Optional[float] = None) -> str:
    """Unused convenience wrapper added for future tax formatting."""
    effective_rate = TAX_RATE if rate is None else rate
    return format_currency(amount * (1 + effective_rate))
EOF
  cat > test_pricing.py <<'EOF'
import unittest
from unittest.mock import patch

from pricing import TAX_RATE, apply_discount, format_currency


class TestPricing(unittest.TestCase):
    def test_tax_rate(self) -> None:
        self.assertEqual(TAX_RATE, 0.08)

    @patch("pricing.apply_discount", return_value=80.0)
    def test_apply_discount_basic(self, mock_apply) -> None:
        result = mock_apply(100, 20)
        self.assertEqual(result, 80.0)
        mock_apply.assert_called_once_with(100, 20)

    def test_format_currency(self) -> None:
        self.assertEqual(format_currency(12.5), "$12.50")


if __name__ == "__main__":
    unittest.main()
EOF
  git add pricing.py test_pricing.py
  git commit -q -m "fix: update apply_discount and clean up pricing helpers"

  # Configured-profile baseline for P2-P6 so /saw-* skills don't stop for setup questions.
  git checkout -q --detach canary-baseline
  cat > .saw/profile.md <<'EOF'
# SAW Project Profile
status: configured

## Settings
default-pack: general
base-branch: main
doc-path: docs/

## Project summary
- Purpose: Minimal Python pricing module (sample app).
- Stack: Python 3 standard library, unittest.

## Project docs
- README.md: functions and how to run tests — read when: changing pricing.py behavior or tests

## Verification commands
lint: not configured
typecheck: not configured
test: python3 -m unittest
build: not configured
runtime: not configured

## Notes & Constraints
- none found
EOF
  git commit -q -am "chore: configure canary profile"
  git tag canary-configured

  git checkout -q main
)

echo "Canary sandbox ready at: $DEST (targets: $TARGETS; tags: canary-baseline, canary-configured)"
echo "Next: run $PROBES_DIR/canary.sh <claude|copilot|antigravity> (see $PROBES_DIR/RUNBOOK.md)"
