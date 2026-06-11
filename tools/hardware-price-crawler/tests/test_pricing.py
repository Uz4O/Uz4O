import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.pricing import (
    HardwareTarget,
    RawProduct,
    assess_product,
    build_reference_price,
)


def product(title: str, price: float, category: str = "gpu") -> RawProduct:
    return RawProduct(
        target_id="rtx-5070",
        category=category,
        query="RTX 5070",
        sku="123",
        title=title,
        price=price,
        shop="京东自营",
        url="https://item.jd.com/123.html",
        captured_at="2026-06-10T20:00:00+08:00",
    )


class ProductAssessmentTests(unittest.TestCase):
    def test_accepts_matching_standalone_gpu(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = assess_product(target, product("华硕 NVIDIA GeForce RTX 5070 12GB 显卡", 4899))

        self.assertTrue(result.accepted)
        self.assertEqual(result.reason, "accepted")

    def test_rejects_different_gpu_variant(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = assess_product(target, product("七彩虹 RTX 5070 Ti 16GB 显卡", 6299))

        self.assertFalse(result.accepted)
        self.assertEqual(result.reason, "model_mismatch")

    def test_rejects_longer_cpu_variant(self):
        target = HardwareTarget("cpu", "i5-14600k", "i5-14600K", "Intel", "LGA1700")
        item = product("Intel i5-14600KF 盒装处理器", 1899, category="cpu")

        result = assess_product(target, item)

        self.assertFalse(result.accepted)
        self.assertEqual(result.reason, "model_mismatch")

    def test_rejects_desktop_bundle(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = assess_product(target, product("RTX 5070 电竞游戏整机台式电脑", 9999))

        self.assertFalse(result.accepted)
        self.assertEqual(result.reason, "excluded_keyword:整机")

    def test_rejects_used_product(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = assess_product(target, product("二手 RTX 5070 显卡", 2999))

        self.assertFalse(result.accepted)
        self.assertEqual(result.reason, "excluded_keyword:二手")

    def test_rejects_price_outside_category_guardrail(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = assess_product(target, product("RTX 5070 显卡支架赠品", 99))

        self.assertFalse(result.accepted)
        self.assertEqual(result.reason, "price_out_of_range")


class ReferencePriceTests(unittest.TestCase):
    def test_no_accepted_products_has_no_reference_price(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")

        result = build_reference_price(target, [])

        self.assertIsNone(result.reference_price)
        self.assertIn("no_accepted_products", result.review_reasons)

    def test_uses_median_and_flags_large_change(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")
        products = [
            product("品牌A RTX 5070 显卡", 4799),
            product("品牌B RTX 5070 显卡", 4899),
            product("品牌C RTX 5070 显卡", 4999),
        ]
        assessments = [assess_product(target, item) for item in products]

        result = build_reference_price(target, assessments, previous_price=3999)

        self.assertEqual(result.reference_price, 4899)
        self.assertEqual(result.normal_price_min, 4799)
        self.assertEqual(result.normal_price_max, 4999)
        self.assertIn("price_changed_over_20_percent", result.review_reasons)

    def test_requires_review_when_fewer_than_two_products_are_accepted(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")
        assessments = [assess_product(target, product("品牌A RTX 5070 显卡", 4899))]

        result = build_reference_price(target, assessments)

        self.assertEqual(result.reference_price, 4899)
        self.assertIn("insufficient_accepted_products", result.review_reasons)

    def test_removes_extreme_price_outlier(self):
        target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")
        products = [
            product("品牌A RTX 5070 显卡", 699),
            product("品牌B RTX 5070 显卡", 4799),
            product("品牌C RTX 5070 显卡", 4899),
        ]
        assessments = [assess_product(target, item) for item in products]

        result = build_reference_price(target, assessments)

        self.assertEqual(result.reference_price, 4849)
        self.assertEqual(result.normal_price_min, 4799)
        self.assertEqual(result.normal_price_max, 4899)
        self.assertIn("price_outliers_removed", result.review_reasons)


if __name__ == "__main__":
    unittest.main()
