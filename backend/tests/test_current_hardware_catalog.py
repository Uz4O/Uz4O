from pathlib import Path

from app.catalog.seed import extract_catalog_components


def test_current_swift_catalog_extracts_715_components() -> None:
    catalog_path = Path("../May/May/Models/HardwareCatalog.swift")

    components = extract_catalog_components(catalog_path)

    assert len(components) == 715
    assert {component.category for component in components} == {
        "cpu",
        "gpu",
        "motherboard",
        "ram",
        "storage",
        "psu",
    }
    assert len({component.id for component in components}) == 715

    cpus = [component for component in components if component.category == "cpu"]
    gpus = [component for component in components if component.category == "gpu"]
    motherboards = [component for component in components if component.category == "motherboard"]
    assert all("perf_index" in component.specs for component in cpus)
    assert all("tdp" in component.specs for component in cpus)
    assert all("perf_index" in component.specs for component in gpus)
    assert all("tdp" in component.specs for component in gpus)
    assert all("form_factor" in component.specs for component in motherboards)
    assert sum("mem_type" in component.specs for component in motherboards) > 400
