import json
from pathlib import Path

import pytest

from app.cli import main
from app.perf.importer import read_performance_batch


def batch_payload(**record_overrides):
    record = {
        "cpu_id": "r5-5600",
        "gpu_id": "rtx-4060",
        "game_id": "cyberpunk-2077",
        "resolution": "1080p",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "cpu",
        "bottleneck_percent": 11,
        "source_url": "https://pc-builds.com/example",
        "response_hash": "sha256",
    }
    record.update(record_overrides)
    return {
        "generated_at": "2026-07-12T00:00:00+00:00",
        "import_batch": "reviewed-20260712",
        "quality": "medium",
        "records": [record],
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


def test_import_reads_reviewed_medium_record(tmp_path) -> None:
    path = write_batch(tmp_path / "reviewed.json", batch_payload())

    records = read_performance_batch(path)

    assert len(records) == 1
    assert records[0].quality == "medium"
    assert records[0].resolution == "1080p"
    assert records[0].source_fetched_at.utcoffset() is not None
    assert records[0].import_batch == "reviewed-20260712"


@pytest.mark.parametrize(
    ("payload", "message"),
    [
        (batch_payload(resolution="720p"), "resolution"),
        ({**batch_payload(), "quality": "high"}, "quality"),
        ({**batch_payload(), "generated_at": "2026-07-12T00:00:00"}, "timezone"),
        (batch_payload(source_url="not-a-url"), "source_url"),
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
        ["ai-pc-builder-api", "import-perf-estimates", str(path)],
    )

    main()

    assert captured["rows"][0].import_batch == "reviewed-20260712"
    assert capsys.readouterr().out == "Imported 1 game performance estimates.\n"
