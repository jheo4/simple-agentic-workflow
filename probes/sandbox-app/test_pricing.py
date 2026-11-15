import unittest

from pricing import TAX_RATE, apply_discount, format_currency


class TestPricing(unittest.TestCase):
    def test_tax_rate(self) -> None:
        self.assertEqual(TAX_RATE, 0.08)

    def test_apply_discount_basic(self) -> None:
        self.assertEqual(apply_discount(100, 20), 80.0)

    def test_format_currency(self) -> None:
        self.assertEqual(format_currency(12.5), "$12.50")


if __name__ == "__main__":
    unittest.main()
