import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from price_crawler.catalog import extract_hardware_targets


CATALOG_FIXTURE = """
enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "i5-14600k", name: "i5-14600K", brand: "Intel", detail: "LGA1700")
    ]

    static let gpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "rtx-5070", name: "RTX 5070", brand: "NVIDIA", detail: "NVIDIA")
    ]

    static let motherboards: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "b760m", name: "B760M AORUS ELITE", brand: "技嘉", detail: "LGA1700")
    ]

    static let storages: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "sn850x", name: "SN850X", brand: "WD", detail: "1TB")
    ]
}
"""


class CatalogExtractionTests(unittest.TestCase):
    def test_extracts_only_selected_categories(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "HardwareCatalog.swift"
            path.write_text(CATALOG_FIXTURE, encoding="utf-8")

            targets = extract_hardware_targets(path)

        self.assertEqual([target.category for target in targets], ["cpu", "gpu", "motherboard"])
        self.assertEqual([target.name for target in targets], ["i5-14600K", "RTX 5070", "B760M AORUS ELITE"])


if __name__ == "__main__":
    unittest.main()

