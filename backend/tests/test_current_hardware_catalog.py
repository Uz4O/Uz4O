from pathlib import Path

from app.catalog.prices import (
    read_approved_price_rows,
    read_cpu_whitelist_price_rows,
    read_gpu_whitelist_price_rows,
    read_motherboard_whitelist_price_rows,
)
from app.catalog.rule_specs import GPU_PERFORMANCE, OFFICE_ONLY_GPU_RULE_SPECS
from app.catalog.seed import extract_catalog_components, read_catalog_components


def test_current_swift_catalog_extracts_733_components() -> None:
    catalog_path = Path("../May/May/Models/HardwareCatalog.swift")

    components = extract_catalog_components(catalog_path)

    assert len(components) == 733
    assert {component.category for component in components} == {
        "cpu",
        "gpu",
        "motherboard",
        "ram",
        "storage",
        "psu",
    }
    assert len({component.id for component in components}) == 733

    cpus = [component for component in components if component.category == "cpu"]
    gpus = [component for component in components if component.category == "gpu"]
    motherboards = [component for component in components if component.category == "motherboard"]
    assert all("perf_index" in component.specs for component in cpus)
    assert all("tdp" in component.specs for component in cpus)
    assert {"u5-225f", "u5-250-plus", "u7-270-plus"}.issubset(
        {component.id for component in cpus}
    )
    assert all("perf_index" in component.specs for component in gpus)
    assert all("tdp" in component.specs for component in gpus)
    assert {
        "arc-a580-8gb",
        "arc-a770-16gb",
        "arc-b570-10gb",
        "arc-b580-12gb",
    }.issubset({component.id for component in gpus})
    assert all("form_factor" in component.specs for component in motherboards)
    assert sum("mem_type" in component.specs for component in motherboards) > 400


def test_current_cpu_whitelist_includes_productivity_additions() -> None:
    rows = read_cpu_whitelist_price_rows(
        Path("data/cpu-whitelist-prices-2026-07-07.csv"),
        approved_at="2026-07-20",
    )
    prices = {row.component_id: row for row in rows}
    expected_new_prices = {
        "i5-14400f": 900,
        "i7-13700kf": 1750,
        "u5-245k": 1090,
        "u5-250-plus": 1450,
        "u7-265k": 1799,
        "u7-270-plus": 2100,
    }

    assert {
        component_id: prices[component_id].new_tray_price
        for component_id in expected_new_prices
    } == expected_new_prices
    expected_used_prices = {
        "i5-14400f": 900,
        "i7-13700kf": 1450,
        "u5-245k": 850,
        "u5-250-plus": 1300,
        "u7-265k": 1500,
        "u7-270-plus": 2000,
    }
    assert {
        component_id: prices[component_id].used_price
        for component_id in expected_used_prices
    } == expected_used_prices
    assert all(
        prices[component_id].used_price is None
        for component_id in expected_new_prices.keys() - expected_used_prices.keys()
    )
    assert {
        "i5-14600kf",
        "i7-14700kf",
        "i9-14900kf",
        "u5-225f",
    }.isdisjoint(prices)


def test_current_gpu_whitelist_contains_priced_office_only_intel_arc_models() -> None:
    rows = read_gpu_whitelist_price_rows(
        Path("data/gpu-whitelist-prices-2026-07-07.csv"),
        approved_at="2026-07-20",
    )
    prices = {row.component_id: row for row in rows}
    office_only_ids = {
        "arc-a580-8gb",
        "arc-a770-16gb",
        "arc-b570-10gb",
        "arc-b580-12gb",
    }

    expected_prices = {
        "arc-a580-8gb": (850, 1400),
        "arc-a770-16gb": (1300, 2000),
        "arc-b570-10gb": (1300, 2000),
        "arc-b580-12gb": (1500, 2500),
    }

    assert office_only_ids.issubset(prices)
    assert {
        component_id: (
            prices[component_id].used_price,
            prices[component_id].new_price,
        )
        for component_id in office_only_ids
    } == expected_prices
    assert office_only_ids == set(OFFICE_ONLY_GPU_RULE_SPECS)
    assert office_only_ids.isdisjoint(GPU_PERFORMANCE)


def test_current_gpu_whitelist_contains_user_confirmed_rtx_50_series_prices() -> None:
    rows = read_gpu_whitelist_price_rows(
        Path("data/gpu-whitelist-prices-2026-07-07.csv"),
        approved_at="2026-08-22",
    )
    prices = {row.component_id: row for row in rows}
    expected_prices = {
        "rtx-5060": (2650, 3299),
        "rtx-5060-ti": (3099, 3599),
        "rtx-5070": (5999, 6999),
        "rtx-5070-ti": (7299, 9799),
        "rtx-5080": (10500, 13499),
        "rtx-5090-d-v2": (19000, 22999),
        "rtx-5090": (None, 32999),
    }

    assert {
        component_id: (
            prices[component_id].used_price,
            prices[component_id].new_price,
        )
        for component_id in expected_prices
    } == expected_prices
    assert "rtx-5090-d" not in prices


def test_current_gpu_whitelist_contains_user_confirmed_used_rtx_40_series_prices() -> None:
    rows = read_gpu_whitelist_price_rows(
        Path("data/gpu-whitelist-prices-2026-07-07.csv"),
        approved_at="2026-08-22",
    )
    prices = {row.component_id: row for row in rows}
    expected_used_prices = {
        "rtx-4060": 1999,
        "rtx-4060-ti": 2300,
        "rtx-4070": 3299,
        "rtx-4070-super": 3700,
        "rtx-4070-ti": 4200,
        "rtx-4070-ti-super": 4799,
        "rtx-4080": 6900,
        "rtx-4080-super": 7300,
        "rtx-4090": 21000,
        "rtx-4090-d": 15500,
    }

    assert {
        component_id: prices[component_id].used_price
        for component_id in expected_used_prices
    } == expected_used_prices
    assert all(prices[component_id].new_price is None for component_id in expected_used_prices)
    assert (
        GPU_PERFORMANCE["rtx-5090-d-v2"]
        > GPU_PERFORMANCE["rtx-4090"]
        > GPU_PERFORMANCE["rtx-4090-d"]
        > GPU_PERFORMANCE["rtx-5080"]
    )


def test_current_motherboard_whitelist_contains_15th_gen_productivity_boards() -> None:
    rows = read_motherboard_whitelist_price_rows(
        Path("data/motherboard-whitelist-prices-2026-07-07.csv"),
        approved_at="2026-07-20",
    )
    prices = {row.component_id: row for row in rows}
    expected_prices = {
        "asus-b860m-k": (550, 700),
        "msi-pro-b860m-a": (750, 1050),
        "msi-b860m-mortar": (900, 1200),
    }

    assert {
        component_id: (
            prices[component_id].used_price,
            prices[component_id].new_price,
        )
        for component_id in expected_prices
    } == expected_prices
    assert all(prices[component_id].platform == "LGA1851" for component_id in expected_prices)
    assert all(prices[component_id].status == "active" for component_id in expected_prices)


def test_intel_productivity_ddr5_default_has_user_provided_price() -> None:
    components = read_catalog_components(
        Path("data/office-build-support-components-2026-07-20.json")
    )
    assert len(components) == 1
    component = components[0]
    assert component.id == "office-ddr5-16gb-7200-c36"
    assert component.specs == {
        "type": "DDR5",
        "capacity_gb": 16,
        "speed_mhz": 7200,
        "cas_latency": 36,
        "modules": 1,
        "cpu_vendor": "Intel",
        "usage_scope": "productivity",
    }

    prices = read_approved_price_rows(
        Path("data/office-build-reference-prices-2026-07-20.csv"),
        approved_at="2026-07-20",
    )
    assert len(prices) == 1
    assert prices[0].component_id == component.id
    assert prices[0].reference_price == 1800
