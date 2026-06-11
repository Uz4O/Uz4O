import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.pricing import HardwareTarget, ProductAssessment, RawProduct, ReferencePrice
from price_crawler.storage import (
    read_previous_prices,
    write_hardware_targets,
    write_raw_products,
    write_reference_prices,
    write_review_required,
)


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.target = HardwareTarget("gpu", "rtx-5070", "RTX 5070", "NVIDIA", "NVIDIA")
        self.product = RawProduct(
            "rtx-5070",
            "gpu",
            "RTX 5070",
            "123",
            "RTX 5070 显卡",
            4899,
            "京东自营",
            "https://item.jd.com/123.html",
            "2026-06-10T20:00:00+08:00",
        )
        self.reference = ReferencePrice(
            target=self.target,
            reference_price=4899,
            normal_price_min=4799,
            normal_price_max=4999,
            accepted_count=3,
            rejected_count=1,
            review_reasons=("price_changed_over_20_percent",),
        )

    def test_writes_all_report_types_and_reads_previous_prices(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hardware_path = root / "hardware.csv"
            raw_path = root / "raw.csv"
            reference_path = root / "reference.csv"
            review_path = root / "review.csv"

            write_hardware_targets(hardware_path, [self.target])
            write_raw_products(raw_path, [self.product])
            write_reference_prices(reference_path, [self.reference])
            write_review_required(
                review_path,
                [self.reference],
                [ProductAssessment(self.product, False, "excluded_keyword:整机")],
            )

            previous = read_previous_prices(reference_path)
            with review_path.open(encoding="utf-8", newline="") as handle:
                review_rows = list(csv.DictReader(handle))

        self.assertEqual(previous, {"rtx-5070": 4899.0})
        self.assertEqual(review_rows[0]["record_type"], "reference")
        self.assertEqual(review_rows[1]["record_type"], "rejected_product")

    def test_previous_prices_skips_blank_reference_price(self):
        empty_reference = ReferencePrice(
            target=self.target,
            reference_price=None,
            normal_price_min=None,
            normal_price_max=None,
            accepted_count=0,
            rejected_count=0,
            review_reasons=("no_accepted_products",),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reference.csv"
            write_reference_prices(path, [empty_reference])

            previous = read_previous_prices(path)

        self.assertEqual(previous, {})


if __name__ == "__main__":
    unittest.main()
