import json
from pathlib import Path

from app.cli import main
from app.catalog.seed import extract_catalog_components, parse_detail_specs, read_catalog_components


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
        "perf_index": 84,
        "tdp": 181,
    }


def test_reads_backend_only_catalog_components_from_json(tmp_path: Path) -> None:
    path = tmp_path / "support-components.json"
    path.write_text(
        """
        [
          {
            "id": "base-case",
            "category": "case",
            "name": "普通中塔机箱",
            "brand": "通用规格",
            "detail_raw": "普通中塔",
            "specs": {"form_factor": "atx_mid_tower"},
            "used_price": 80,
            "new_price": 100
          }
        ]
        """,
        encoding="utf-8",
    )

    components = read_catalog_components(path)

    assert len(components) == 1
    assert components[0].id == "base-case"
    assert components[0].category == "case"
    assert components[0].specs == {"form_factor": "atx_mid_tower"}


def test_seed_hardware_cli_imports_backend_only_json_components(
    monkeypatch,
    tmp_path: Path,
    capsys,
) -> None:
    captured = {}
    path = tmp_path / "support-components.json"
    path.write_text(
        """
        [
          {
            "id": "base-case",
            "category": "case",
            "name": "普通中塔机箱",
            "brand": "通用规格",
            "detail_raw": "普通中塔",
            "specs": {"form_factor": "atx_mid_tower"}
          }
        ]
        """,
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_seed_hardware_components(session, components):
        captured["components"] = components
        return len(components)

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr(
        "app.cli.seed_hardware_components",
        fake_seed_hardware_components,
    )
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", "seed-hardware", str(path)],
    )

    main()

    assert [component.id for component in captured["components"]] == ["base-case"]
    assert capsys.readouterr().out == "Seeded 1 hardware components.\n"


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


def test_enriches_cpu_gpu_and_motherboard_specs_for_rules() -> None:
    cpu_specs = parse_detail_specs("cpu", "14代 Raptor Lake Refresh · LGA1700", name="i7-14700F")
    assert cpu_specs["socket"] == "LGA1700"
    assert cpu_specs["perf_index"] > 80
    assert cpu_specs["tdp"] >= 150

    gpu_specs = parse_detail_specs("gpu", "NVIDIA", name="RTX 4070")
    assert gpu_specs["vendor"] == "NVIDIA"
    assert gpu_specs["perf_index"] > parse_detail_specs("gpu", "NVIDIA", name="RTX 4060")["perf_index"]
    assert gpu_specs["tdp"] >= 180

    am5_board_specs = parse_detail_specs("motherboard", "AMD · AM5 · B650", name="B650M MORTAR")
    assert am5_board_specs["mem_type"] == "DDR5"
    assert am5_board_specs["form_factor"] == "micro_atx"

    lga1200_board_specs = parse_detail_specs("motherboard", "Intel · LGA1200 · B460", name="B460M Mortar")
    assert lga1200_board_specs["mem_type"] == "DDR4"

    board_power_specs = parse_detail_specs(
        "motherboard",
        "Intel · LGA1851 · B860",
        name="B860 DS3H",
        component_id="gigabyte-b860-ds3h",
    )
    assert board_power_specs["cpu_power_phases"] == 8
    assert board_power_specs["phase_watts"] == 25
    assert board_power_specs["cpu_power_limit"] == 200


def test_official_motherboard_power_data_is_traceable_and_uses_25_watts_per_phase() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    data = json.loads(
        (backend_root / "data" / "motherboard-official-specs.json").read_text(encoding="utf-8")
    )
    catalog = extract_catalog_components(
        backend_root.parent / "May" / "May" / "Models" / "HardwareCatalog.swift"
    )
    motherboard_ids = {item.id for item in catalog if item.category == "motherboard"}
    exact = [row for row in data if row["status"] == "exact" and row["cpu_power_phases"]]

    assert len(exact) >= 260
    assert len({row["component_id"] for row in data}) == len(data)
    assert {row["component_id"] for row in data} <= motherboard_ids
    for row in exact:
        assert 3 <= row["cpu_power_phases"] <= 30
        assert row["phase_watts"] == 25
        assert row["cpu_power_limit"] == row["cpu_power_phases"] * 25
        assert row["source_url"].startswith("https://")
        assert row["evidence"] == "manufacturer_official"


def test_whitelist_gpu_rule_specs_override_seed_heuristics() -> None:
    assert parse_detail_specs(
        "gpu",
        "AMD",
        name="RX 7650 GRE",
        component_id="rx-7650-gre",
    ) == {
        "vendor": "AMD",
        "perf_index": 43,
        "tdp": 230,
    }
    assert parse_detail_specs(
        "gpu",
        "AMD",
        name="RX 7700 XT",
    ) == {
        "vendor": "AMD",
        "perf_index": 55,
        "tdp": 245,
    }
