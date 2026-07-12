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

    assert (len(manifest.cpus), len(manifest.gpus), len(manifest.games)) == (101, 77, 15)
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

    assert (len(cpus), len(gpus)) == (101, 77)
    assert cpus[0].app_id == "i9-14900ks"
    assert gpus[0].app_id == "rtx-5090"


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
    assert capsys.readouterr().out == "Wrote 101 CPUs, 77 GPUs, and 15 games.\n"


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
