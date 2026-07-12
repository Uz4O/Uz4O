import json
from datetime import datetime
from pathlib import Path

import pytest

from app.cli import main
from app.perf.collector import CollectionBlocked, RunSummary
from app.perf.collector_parser import ParsedPerformanceRow
from app.perf.collector_store import CollectionTask, CollectorStore


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "backend/data/pc-builds-fps-mappings.json"
EXPECTED_URL = (
    "https://pc-builds.com/zh/fps-calculator/result/1fB1ge02g/"
    "ryzen-5-5600/geforce-rtx-4060/cyberpunk-2077/1920x1080/"
)


def invoke(monkeypatch, *args: str) -> None:
    monkeypatch.setattr("sys.argv", ["ai-pc-builder-api", *args])
    main()


def test_seed_command_builds_exact_mapping_cross_product(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    database = tmp_path / "perf.sqlite"

    invoke(monkeypatch, "seed-perf-collection", str(MANIFEST_PATH), str(database))

    assert capsys.readouterr().out == "Seeded 1 tasks.\n"
    with CollectorStore(database) as store:
        claimed = store.claim_next()
        assert claimed is not None
        assert (
            claimed.cpu_id,
            claimed.gpu_id,
            claimed.game_id,
            claimed.source_url,
        ) == ("r5-5600", "rtx-4060", "cyberpunk-2077", EXPECTED_URL)


def test_run_command_builds_client_and_passes_options(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    seen = {}

    class FakeClient:
        def __init__(self, *, timeout):
            seen["timeout"] = timeout

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

    class FakeCollector:
        def __init__(self, store, client, policy):
            seen["path"] = store
            seen["client"] = client
            seen["policy"] = policy

        def run(self, max_tasks=None):
            seen["max_tasks"] = max_tasks
            return RunSummary(processed=2, succeeded=1, missing=1)

    monkeypatch.setattr("app.cli.httpx.Client", FakeClient)
    monkeypatch.setattr("app.cli.Collector", FakeCollector)

    invoke(
        monkeypatch,
        "run-perf-collection",
        str(tmp_path / "perf.sqlite"),
        "--max-tasks",
        "2",
        "--delay-seconds",
        "0.5",
    )

    assert seen["timeout"] == 20.0
    assert seen["client"] is not None
    assert seen["policy"].delay_seconds == 0.5
    assert seen["max_tasks"] == 2
    assert "processed=2 succeeded=1 missing=1" in capsys.readouterr().out


def test_run_command_exits_nonzero_when_collection_blocks(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    class FakeClient:
        def __init__(self, **kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

    class FakeCollector:
        def __init__(self, *args, **kwargs):
            pass

        def run(self, max_tasks=None):
            raise CollectionBlocked("HTTP 429 retry_after=60")

    monkeypatch.setattr("app.cli.httpx.Client", FakeClient)
    monkeypatch.setattr("app.cli.Collector", FakeCollector)

    with pytest.raises(SystemExit) as error:
        invoke(monkeypatch, "run-perf-collection", str(tmp_path / "perf.sqlite"))

    assert error.value.code == 2
    assert "blocked: HTTP 429 retry_after=60" in capsys.readouterr().out


def test_run_command_rejects_negative_max_tasks(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "run-perf-collection",
            str(tmp_path / "perf.sqlite"),
            "--max-tasks",
            "-1",
        ],
    )

    with pytest.raises(SystemExit) as error:
        main()

    assert error.value.code == 2
    assert "non-negative" in capsys.readouterr().err


def test_run_command_allows_large_delay_when_no_tasks_are_requested(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    invoke(
        monkeypatch,
        "run-perf-collection",
        str(tmp_path / "perf.sqlite"),
        "--max-tasks",
        "0",
        "--delay-seconds",
        "40",
    )

    captured = capsys.readouterr()
    assert "processed=0" in captured.out
    assert captured.err == ""


def test_export_command_flattens_only_valid_succeeded_results(
    monkeypatch, tmp_path: Path, capsys
) -> None:
    database = tmp_path / "perf.sqlite"
    output = tmp_path / "nested/perf.json"
    rows = [
        ParsedPerformanceRow("1080p", 77, 66, 89, "gpu", 5),
        ParsedPerformanceRow("2k", 58, 49, 66, "gpu", 8),
        ParsedPerformanceRow("4k", 38, 32, 44, "balanced", 0),
    ]
    with CollectorStore(database) as store:
        store.seed_tasks(
            [
                CollectionTask("cpu", "gpu", "game", EXPECTED_URL),
                CollectionTask(
                    "pending", "pending", "pending", EXPECTED_URL + "pending"
                ),
            ]
        )
        claimed = store.claim_next()
        assert claimed is not None
        store.record_success(claimed.id, rows, "response-hash")

    invoke(monkeypatch, "export-perf-collection", str(database), str(output))

    assert capsys.readouterr().out == "Exported 3 records.\n"
    payload = json.loads(output.read_text(encoding="utf-8"))
    assert payload["quality"] == "medium"
    assert datetime.fromisoformat(payload["generated_at"]).tzinfo is not None
    assert [record["resolution"] for record in payload["records"]] == [
        "1080p",
        "2k",
        "4k",
    ]
    assert payload["records"][0] == {
        "cpu_id": "cpu",
        "gpu_id": "gpu",
        "game_id": "game",
        "source_url": EXPECTED_URL,
        "response_hash": "response-hash",
        "resolution": "1080p",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "gpu",
        "bottleneck_percent": 5,
    }
    assert list(output.parent.glob(f".{output.name}.*.tmp")) == []
