import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.scraper import parse_price


class PriceParsingTests(unittest.TestCase):
    def test_parses_currency_and_comma(self):
        self.assertEqual(parse_price("¥ 4,899.00"), 4899.0)

    def test_returns_none_for_missing_price(self):
        self.assertIsNone(parse_price("暂无报价"))


if __name__ == "__main__":
    unittest.main()

