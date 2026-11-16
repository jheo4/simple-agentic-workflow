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

  # Canary branches for P6 (/saw-diff-commit); main stays unchanged for P1-P5.
  git checkout -q -b canary/clean-fix main
  cat > pricing.py <<'EOF'
"""Minimal sandbox module for SAW canary probes."""

TAX_RATE = 0.08


def apply_discount(price: float, pct: float) -> float:
    """Return final price after applying percentage discount pct (0..100)."""
    return price * (1 - pct / 100)


def format_currency(  amount: float ) -> str:
    # Intentionally quirky spacing untouched by discount tasks (Minimal Diff trap).
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

  git checkout -q main
)

echo "Canary sandbox ready at: $DEST (targets: $TARGETS)"
echo "Next: open $DEST in your target harness and follow $PROBES_DIR/RUNBOOK.md"
