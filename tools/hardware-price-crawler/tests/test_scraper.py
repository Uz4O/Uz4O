import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.cli import DEFAULT_PLATFORM
from price_crawler.scraper import login_url_for_platform, parse_price, search_url_for_platform


class PriceParsingTests(unittest.TestCase):
    def test_parses_currency_and_comma(self):
        self.assertEqual(parse_price("¥ 4,899.00"), 4899.0)

    def test_returns_none_for_missing_price(self):
        self.assertIsNone(parse_price("暂无报价"))

    def test_default_platform_is_taobao(self):
        self.assertEqual(DEFAULT_PLATFORM, "taobao")

    def test_builds_taobao_search_url(self):
        self.assertEqual(
            search_url_for_platform("taobao", "RTX 5070 显卡"),
            "https://s.taobao.com/search?q=RTX%205070%20%E6%98%BE%E5%8D%A1",
        )

    def test_keeps_jd_search_url_available(self):
        self.assertEqual(
            search_url_for_platform("jd", "RTX 5070 显卡"),
            "https://search.jd.com/Search?keyword=RTX%205070%20%E6%98%BE%E5%8D%A1",
        )

    def test_taobao_login_url(self):
        self.assertEqual(login_url_for_platform("taobao"), "https://www.taobao.com/")


if __name__ == "__main__":
    unittest.main()
