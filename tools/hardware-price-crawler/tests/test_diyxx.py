import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.diyxx import (
    DiyxxGPUProduct,
    match_whitelist_target,
    write_diyxx_gpu_snapshot,
)


WHITELIST = [
    {"target_id": "rtx-5060", "name": "RTX 5060"},
    {"target_id": "rtx-5060-ti", "name": "RTX 5060 Ti"},
    {"target_id": "rtx-5090", "name": "RTX 5090"},
    {"target_id": "rtx-5090-d", "name": "RTX 5090 D"},
    {"target_id": "rtx-5090-d-v2", "name": "RTX 5090 D V2"},
    {"target_id": "rx-9060-xt-8gb", "name": "RX 9060 XT 8G"},
    {"target_id": "rx-9060-xt-12gb", "name": "RX 9060 XT 12G"},
]


def product(product_id: str, model: str, price: int, memory_size=None) -> DiyxxGPUProduct:
    return DiyxxGPUProduct(
        product_id=product_id,
        brand="测试品牌",
        model=model,
        price=price,
        previous_price=None,
        updated_at="2026-07-30T10:00:00",
        status="active",
        gpu_chip="",
        memory_size=memory_size,
    )


class DiyxxMatchingTests(unittest.TestCase):
    def test_prefers_specific_ti_model(self):
        self.assertEqual(
            match_whitelist_target(product("1", "RTX5060TI 魔刃 8G", 3400), WHITELIST),
            "rtx-5060-ti",
        )

    def test_distinguishes_5090_variants(self):
        self.assertEqual(
            match_whitelist_target(product("1", "5090D ADOC 24G V2", 23000), WHITELIST),
            "rtx-5090-d-v2",
        )
        self.assertEqual(
            match_whitelist_target(product("2", "ROG RTX5090D O32G", 30000), WHITELIST),
            "rtx-5090-d",
        )
        self.assertEqual(
            match_whitelist_target(product("3", "ROG RTX5090 O32G", 35000), WHITELIST),
            "rtx-5090",
        )

    def test_requires_the_whitelisted_9060_memory_size(self):
        self.assertEqual(
            match_whitelist_target(product("1", "9060XT 8G 脉动", 2400, 8), WHITELIST),
            "rx-9060-xt-8gb",
        )
        self.assertIsNone(
            match_whitelist_target(product("2", "9060XT 16G 脉动", 3200, 16), WHITELIST)
        )


class DiyxxSnapshotTests(unittest.TestCase):
    def test_writes_all_products_and_uses_the_lowest_matching_price(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            whitelist = root / "whitelist.csv"
            whitelist.write_text(
                "target_id,name,used_price,new_price\n"
                "rtx-5060,RTX 5060,2200,2300\n"
                "rtx-5090,RTX 5090,,30000\n",
                encoding="utf-8",
            )
            summary = write_diyxx_gpu_snapshot(
                root / "output",
                whitelist,
                [
                    product("higher", "RTX5060 魔刃 8G", 2900),
                    product("lowest", "RTX5060 幻影师 2X", 2800),
                ],
            )
            with (root / "output/gpu-whitelist-prices.csv").open(
                encoding="utf-8", newline=""
            ) as handle:
                rows = list(csv.DictReader(handle))

        self.assertEqual(summary["product_count"], 2)
        self.assertEqual(summary["matched_whitelist_count"], 1)
        self.assertEqual(rows[0]["name"], "测试品牌 RTX5060 幻影师 2X")
        self.assertEqual(rows[0]["used_price"], "2200")
        self.assertEqual(rows[0]["new_price"], "2800")
        self.assertEqual(rows[0]["source_product_id"], "lowest")
        self.assertEqual(rows[1]["name"], "RTX 5090")
        self.assertEqual(rows[1]["new_price"], "30000")


if __name__ == "__main__":
    unittest.main()
