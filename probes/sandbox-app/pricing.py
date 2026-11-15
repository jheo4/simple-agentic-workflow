"""Minimal sandbox module for SAW canary probes."""

TAX_RATE = 0.08


def apply_discount(price: float, pct: float) -> float:
    """Return final price after applying percentage discount pct (0..100)."""
    # Intentional canary bug: returns discount amount instead of remaining price.
    return price * pct / 100


def format_currency(  amount: float ) -> str:
    # Intentionally quirky spacing untouched by discount tasks (Minimal Diff trap).
    symbol   =   "$"
    formatted = f"{symbol}{amount:.2f}"
    return formatted
