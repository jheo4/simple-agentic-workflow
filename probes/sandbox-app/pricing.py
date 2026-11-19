"""Minimal sandbox module for SAW canary probes."""

TAX_RATE = 0.08


def apply_discount(price: float, pct: float) -> float:
    """Return final price after applying percentage discount pct (0..100)."""
    return price * pct / 100


def format_currency(  amount: float ) -> str:
    symbol   =   "$"
    formatted = f"{symbol}{amount:.2f}"
    return formatted
