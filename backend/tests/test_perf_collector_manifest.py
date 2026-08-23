import json
from pathlib import Path

import pytest

from app.cli import main
from app.perf.collector_manifest import (
    CollectorManifest,
    SourceMapping,
    extract_hardware_scope,
    load_manifest,
    target_page_count,
)


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "backend/data/pc-builds-fps-mappings.json"
SWIFT_CATALOG_PATH = ROOT / "May/May/Models/HardwareCatalog.swift"


def test_committed_manifest_covers_app_scope() -> None:
    manifest = load_manifest(MANIFEST_PATH)
    swift_cpus, swift_gpus = extract_hardware_scope(SWIFT_CATALOG_PATH)

    assert (len(manifest.cpus), len(manifest.gpus), len(manifest.games)) == (104, 82, 15)
    assert [(item.app_id, item.app_name) for item in manifest.cpus] == [
        (item.app_id, item.app_name) for item in swift_cpus
    ]
    assert [(item.app_id, item.app_name) for item in manifest.gpus] == [
        (item.app_id, item.app_name) for item in swift_gpus
    ]
    assert {item.device_type for item in manifest.cpus + manifest.gpus} == {"desktop"}
    assert [game.app_id for game in manifest.games] == [
        "valorant",
        "cs2",
        "pubg",
        "delta-force",
        "teamfight-tactics",
        "league-of-legends",
        "call-of-duty-warzone",
        "cyberpunk-2077",
        "red-dead-redemption-2",
        "gta-v",
        "black-myth-wukong",
        "forza-horizon-6",
        "elden-ring",
        "cities-skylines",
        "minecraft-java-edition",
    ]
    warzone = next(game for game in manifest.games if game.app_id == "call-of-duty-warzone")
    assert warzone.source_name == "Call of Duty: Warzone"

    exact = {
        item.app_id: (item.source_id, item.source_slug, item.source_name)
        for item in manifest.cpus + manifest.gpus + manifest.games
        if item.status == "exact"
    }
    assert exact == {
        "r5-5600": (
            "1fB",
            "ryzen-5-5600",
            "AMD Ryzen 5 5600 3.50 GHz Desktop",
        ),
        "rtx-4060": (
            "1ge",
            "geforce-rtx-4060",
            "NVIDIA GeForce RTX 4060 8 GB Desktop",
        ),
        "cyberpunk-2077": ("02g", "cyberpunk-2077", "Cyberpunk 2077"),
    }
    assert target_page_count(manifest) == 1


def test_target_page_count_multiplies_exact_mapping_counts() -> None:
    exact = SourceMapping("exact", "Exact", "1", "exact", "Exact", "desktop", "exact")
    review = SourceMapping("review", "Review", None, None, None, "desktop", "review")
    manifest = CollectorManifest(
        cpus=[exact, review],
        gpus=[exact, exact],
        games=[exact, review],
    )

    assert target_page_count(manifest) == 2


def test_load_manifest_rejects_incomplete_exact_mapping(tmp_path: Path) -> None:
    path = tmp_path / "manifest.json"
    path.write_text(
        json.dumps(
            {
                "cpus": [
                    {
                        "app_id": "cpu",
                        "app_name": "CPU",
                        "source_id": "1",
                        "source_slug": None,
                        "source_name": "CPU",
                        "device_type": "desktop",
                        "status": "exact",
                    }
                ],
                "gpus": [],
                "games": [],
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="exact mapping"):
        load_manifest(path)


def test_extracts_real_swift_cpu_and_gpu_scope() -> None:
    cpus, gpus = extract_hardware_scope(SWIFT_CATALOG_PATH)

    assert (len(cpus), len(gpus)) == (104, 82)
    assert cpus[0].app_id == "i9-14900ks"
    assert gpus[0].app_id == "arc-b580-12gb"
    assert gpus[4].app_id == "rtx-5090"


def test_extracts_multiline_hardware_initializers(tmp_path: Path) -> None:
    path = tmp_path / "HardwareCatalog.swift"
    path.write_text(
        """
enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(
            id: "cpu-id", name: "CPU Name", brand: "Brand", detail: "Detail"
        )
    ]
    static let gpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(
            id: "gpu-id", name: "GPU Name", brand: "Brand", detail: "Detail"
        )
    ]
}
""",
        encoding="utf-8",
    )

    cpus, gpus = extract_hardware_scope(path)

    assert [(item.app_id, item.app_name) for item in cpus] == [("cpu-id", "CPU Name")]
    assert [(item.app_id, item.app_name) for item in gpus] == [("gpu-id", "GPU Name")]


def test_rejects_unparsed_hardware_initializer(tmp_path: Path) -> None:
    path = tmp_path / "HardwareCatalog.swift"
    path.write_text(
        """
enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: cpuID, name: "CPU Name", brand: "Brand", detail: "Detail")
    ]
    static let gpus: [HardwareCatalogItem] = [
    ]
}
""",
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match=r"cpus.*1 unparsed"):
        extract_hardware_scope(path)


@pytest.mark.parametrize(
    ("section", "items", "message"),
    [
        (
            "cpus",
            [
                {
                    "app_id": "duplicate",
                    "app_name": "CPU 1",
                    "source_id": None,
                    "source_slug": None,
                    "source_name": None,
                    "device_type": "desktop",
                    "status": "review",
                },
                {
                    "app_id": "duplicate",
                    "app_name": "CPU 2",
                    "source_id": None,
                    "source_slug": None,
                    "source_name": None,
                    "device_type": "desktop",
                    "status": "review",
                },
            ],
            "duplicate app_id",
        ),
        (
            "cpus",
            [{"app_id": "cpu", "app_name": "CPU", "device_type": "mobile"}],
            "cpus.*desktop",
        ),
        (
            "gpus",
            [{"app_id": "gpu", "app_name": "GPU", "device_type": "mobile"}],
            "gpus.*desktop",
        ),
        (
            "games",
            [{"app_id": "game", "app_name": "Game", "device_type": "desktop"}],
            "games.*game",
        ),
    ],
)
def test_load_manifest_rejects_duplicate_ids_and_wrong_device_types(
    tmp_path: Path, section: str, items: list, message: str
) -> None:
    path = tmp_path / "manifest.json"
    data = {"cpus": [], "gpus": [], "games": []}
    for item in items:
        item.setdefault("source_id", None)
        item.setdefault("source_slug", None)
        item.setdefault("source_name", None)
        item.setdefault("status", "review")
    data[section] = items
    path.write_text(json.dumps(data), encoding="utf-8")

    with pytest.raises(ValueError, match=message):
        load_manifest(path)


def test_write_manifest_replaces_atomically_without_overwriting_on_failure(
    monkeypatch, tmp_path: Path
) -> None:
    swift_path = tmp_path / "HardwareCatalog.swift"
    swift_path.write_text(
        """
enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
    ]
    static let gpus: [HardwareCatalogItem] = [
    ]
}
""",
        encoding="utf-8",
    )
    manifest_path = tmp_path / "manifest.json"
    original = json.dumps({"cpus": [], "gpus": [], "games": []})
    manifest_path.write_text(original, encoding="utf-8")

    def fail_replace(self, target):
        raise RuntimeError("replace failed")

    monkeypatch.setattr(Path, "replace", fail_replace)

    with pytest.raises(RuntimeError, match="replace failed"):
        from app.perf.collector_manifest import write_manifest

        write_manifest(swift_path, manifest_path)

    assert manifest_path.read_text(encoding="utf-8") == original


def test_build_command_preserves_manual_mapping(monkeypatch, tmp_path: Path, capsys) -> None:
    output_path = tmp_path / "manifest.json"
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    data["cpus"][0].update(
        source_id="confirmed-id",
        source_slug="confirmed-slug",
        source_name="Confirmed CPU",
        status="exact",
    )
    output_path.write_text(json.dumps(data), encoding="utf-8")
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", "build-perf-manifest", str(SWIFT_CATALOG_PATH), str(output_path)],
    )

    main()

    rebuilt = load_manifest(output_path)
    assert rebuilt.cpus[0].source_id == "confirmed-id"
    assert rebuilt.cpus[0].source_slug == "confirmed-slug"
    assert rebuilt.cpus[0].source_name == "Confirmed CPU"
    assert rebuilt.cpus[0].status == "exact"
    assert capsys.readouterr().out == "Wrote 104 CPUs, 82 GPUs, and 15 games.\n"


def test_check_command_reports_status_and_page_count(monkeypatch, capsys) -> None:
    manifest = load_manifest(MANIFEST_PATH)
    expected_pages = target_page_count(manifest)
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", "check-perf-manifest", str(MANIFEST_PATH)],
    )

    main()

    output = capsys.readouterr().out
    assert "exact:" in output
    assert "review:" in output
    assert "missing:" in output
    assert f"Derived result-page count: {expected_pages}" in output


def test_check_command_writes_json_coverage_report(monkeypatch, tmp_path, capsys) -> None:
    output_path = tmp_path / "coverage.json"
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "check-perf-manifest",
            str(MANIFEST_PATH),
            "--json",
            str(output_path),
        ],
    )

    main()

    report = json.loads(output_path.read_text(encoding="utf-8"))
    assert report == {
        "sections": {
            "cpus": {"total": 104, "exact": 1, "review": 103, "missing": 0},
            "gpus": {"total": 82, "exact": 1, "review": 81, "missing": 0},
            "games": {"total": 15, "exact": 1, "review": 14, "missing": 0},
        },
        "overall": {"total": 201, "exact": 3, "review": 198, "missing": 0},
        "derived_result_page_count": 1,
    }
    output = capsys.readouterr().out
    assert "exact: 3\n" in output
    assert "review: 198\n" in output
    assert "missing: 0\n" in output
    assert "Derived result-page count: 1\n" in output
