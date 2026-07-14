import json
from pathlib import Path

import pytest

from app.cli import main
from app.perf.importer import DEFAULT_MANIFEST_PATH, read_performance_batch


EXPECTED_URL = (
    "https://pc-builds.com/zh/fps-calculator/result/1fB1ge02g/"
    "ryzen-5-5600/geforce-rtx-4060/cyberpunk-2077/1920x1080/"
)


def batch_payload(**record_overrides):
    record = {
        "cpu_id": "r5-5600",
        "gpu_id": "rtx-4060",
        "game_id": "cyberpunk-2077",
        "source_cpu_id": "1fB",
        "source_gpu_id": "1ge",
        "source_game_id": "02g",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "cpu",
        "bottleneck_percent": 11,
        "source_url": EXPECTED_URL,
        "response_hash": "sha256",
        "source_fetched_at": "2026-07-11T23:45:00+00:00",
    }
    return {
        "generated_at": "2026-07-12T00:00:00+00:00",
        "import_batch": "reviewed-20260712",
        "quality": "medium",
        "records": [
            {**record, "resolution": resolution, **record_overrides}
            for resolution in ("1080p", "2k", "4k")
        ],
    }


def write_batch(path: Path, payload) -> Path:
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def test_import_rejects_invalid_ranges(tmp_path) -> None:
    path = write_batch(
        tmp_path / "bad.json",
        batch_payload(minimum_fps=90, average_fps=80),
    )

    with pytest.raises(ValueError, match="FPS"):
        read_performance_batch(path)


def test_import_rejects_empty_records(tmp_path) -> None:
    payload = batch_payload()
    payload["records"] = []
    path = write_batch(tmp_path / "empty.json", payload)

    with pytest.raises(ValueError, match="records must not be empty"):
        read_performance_batch(path)


def test_import_reads_reviewed_medium_record(tmp_path) -> None:
    path = write_batch(tmp_path / "reviewed.json", batch_payload())

    records = read_performance_batch(path)

    assert len(records) == 3
    assert records[0].quality == "medium"
    assert records[0].resolution == "1080p"
    assert records[0].source_fetched_at.utcoffset() is not None
    assert records[0].import_batch == "reviewed-20260712"


def test_import_uses_each_record_collection_time(tmp_path) -> None:
    path = write_batch(
        tmp_path / "reviewed.json",
        batch_payload(source_fetched_at="2026-07-11T23:45:00+00:00"),
    )

    records = read_performance_batch(path)

    assert records[0].source_fetched_at.isoformat() == "2026-07-11T23:45:00+00:00"


def test_import_rejects_partial_resolution_group(tmp_path) -> None:
    payload = batch_payload()
    payload["records"].pop()
    path = write_batch(tmp_path / "partial.json", payload)

    with pytest.raises(ValueError, match="exactly 1080p, 2k, and 4k"):
        read_performance_batch(path)


def test_import_rejects_duplicate_resolution_in_group(tmp_path) -> None:
    payload = batch_payload()
    payload["records"].append(dict(payload["records"][0]))
    path = write_batch(tmp_path / "duplicate.json", payload)

    with pytest.raises(ValueError, match="duplicate combination"):
        read_performance_batch(path)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("cpu_id", "r5-5600x"),
        ("source_cpu_id", "wrong"),
        ("source_url", EXPECTED_URL.replace("pc-builds.com", "example.com")),
        ("source_url", EXPECTED_URL.replace("cyberpunk-2077", "wrong-game", 1)),
    ],
)
def test_import_rejects_source_identity_mismatches(
    tmp_path, field, value
) -> None:
    path = write_batch(tmp_path / "mismatch.json", batch_payload(**{field: value}))

    with pytest.raises(ValueError, match="source identity"):
        read_performance_batch(path)


@pytest.mark.parametrize("manifest_state", ["missing", "stale"])
def test_import_rejects_missing_or_stale_manifest_mapping(
    tmp_path, manifest_state
) -> None:
    manifest = json.loads(DEFAULT_MANIFEST_PATH.read_text(encoding="utf-8"))
    cpu = next(item for item in manifest["cpus"] if item["app_id"] == "r5-5600")
    if manifest_state == "missing":
        manifest["cpus"].remove(cpu)
    else:
        cpu["source_id"] = "stale"
    manifest_path = write_batch(tmp_path / "manifest.json", manifest)
    batch_path = write_batch(tmp_path / "reviewed.json", batch_payload())

    with pytest.raises(ValueError, match="source identity"):
        read_performance_batch(batch_path, manifest_path)


@pytest.mark.parametrize(
    ("payload", "message"),
    [
        (batch_payload(resolution="720p"), "resolution"),
        ({**batch_payload(), "quality": "high"}, "quality"),
        ({**batch_payload(), "generated_at": "2026-07-12T00:00:00"}, "timezone"),
        (batch_payload(source_url="not-a-url"), "source identity"),
    ],
)
def test_import_rejects_unapproved_batch_values(tmp_path, payload, message) -> None:
    path = write_batch(tmp_path / "bad.json", payload)

    with pytest.raises(ValueError, match=message):
        read_performance_batch(path)


def test_import_command_reads_reviewed_batch_and_upserts(
    monkeypatch, tmp_path, capsys
) -> None:
    path = write_batch(tmp_path / "reviewed.json", batch_payload())
    captured = {}

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return False

    monkeypatch.setattr(
        "app.cli.create_session_factory",
        lambda settings: lambda: FakeSession(),
    )
    monkeypatch.setattr(
        "app.cli.upsert_performance_estimates",
        lambda session, rows: captured.setdefault("rows", rows) and len(rows),
        raising=False,
    )
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "import-perf-estimates",
            str(path),
            "--manifest-json",
            str(DEFAULT_MANIFEST_PATH),
        ],
    )

    main()

    assert captured["rows"][0].import_batch == "reviewed-20260712"
    assert capsys.readouterr().out == "Imported 3 game performance estimates.\n"
