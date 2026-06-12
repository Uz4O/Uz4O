from pathlib import Path

from app.catalog.seed import extract_catalog_components, parse_detail_specs


FIXTURE = """
enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "i5-14600k", name: "i5-14600K", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700")
    ]

    static let gpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "rtx-4070", name: "RTX 4070", brand: "NVIDIA", detail: "NVIDIA")
    ]

    static let motherboards: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "b760m", name: "B760M AORUS ELITE", brand: "技嘉", detail: "Intel · LGA1700 · B760")
    ]

    static let rams: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "ram-6000-cl30", name: "DDR5-6000 CL30", brand: "芝奇", detail: "DDR5 · 32GB (16GBx2) · 6000MHz · CL30")
    ]

    static let storages: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "sn850x", name: "WD Black SN850X", brand: "Western Digital", detail: "1TB · PCIe 4.0")
    ]

    static let powerSupplies: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "psu-rm750e", name: "Corsair RM750e", brand: "Corsair", detail: "750W · 80+ Gold")
    ]
}
"""


def test_extracts_all_hardware_catalog_categories(tmp_path: Path) -> None:
    path = tmp_path / "HardwareCatalog.swift"
    path.write_text(FIXTURE, encoding="utf-8")

    components = extract_catalog_components(path)

    assert [component.category for component in components] == [
        "cpu",
        "gpu",
        "motherboard",
        "ram",
        "storage",
        "psu",
    ]
    assert components[0].id == "i5-14600k"
    assert components[0].specs == {
        "generation": "14代",
        "platform": "Raptor Lake Refresh",
        "socket": "LGA1700",
    }


def test_parses_reliable_specs_by_category() -> None:
    assert parse_detail_specs("motherboard", "Intel · LGA1700 · B760") == {
        "platform": "Intel",
        "socket": "LGA1700",
        "chipset": "B760",
    }
    assert parse_detail_specs("ram", "DDR5 · 32GB (16GBx2) · 6000MHz · CL30") == {
        "type": "DDR5",
        "capacity_gb": 32,
        "speed_mhz": 6000,
        "cas_latency": 30,
    }
    assert parse_detail_specs("storage", "1TB · PCIe 4.0") == {
        "capacity_gb": 1024,
        "type": "PCIe 4.0",
    }
    assert parse_detail_specs("psu", "750W · 80+ Gold") == {
        "watt": 750,
        "rating": "80+ Gold",
    }
