import json
import sqlite3
from datetime import datetime
from pathlib import Path

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.cli import main
from app.db import Base
from app.perf.collector import CollectionBlocked, RunSummary
from app.perf.collector_parser import ParsedPerformanceRow
from app.perf.collector_store import CollectionTask, CollectorStore
from app.perf.models import GamePerformanceAnchor, HardwarePerformanceProfile

from tests.test_perf_anchor_importer import valid_document


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
    with sqlite3.connect(database) as connection:
        assert connection.execute(
            """
            SELECT source_cpu_id, source_gpu_id, source_game_id FROM task
            """
        ).fetchone() == ("1fB", "1ge", "02g")


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
                CollectionTask(
                    "r5-5600",
                    "rtx-4060",
                    "cyberpunk-2077",
                    EXPECTED_URL,
                    source_cpu_id="1fB",
                    source_gpu_id="1ge",
                    source_game_id="02g",
                ),
                CollectionTask(
                    "pending", "pending", "pending", EXPECTED_URL + "pending"
                ),
            ]
        )
        claimed = store.claim_next()
        assert claimed is not None
        fetched_at = "2026-07-12T06:30:00+00:00"
        monkeypatch.setattr(
            "app.perf.collector_store._utc_iso",
            lambda value=None: fetched_at,
        )
        store.record_success(claimed.id, rows, "response-hash")

    invoke(monkeypatch, "export-perf-collection", str(database), str(output))

    assert capsys.readouterr().out == "Exported 3 records.\n"
    payload = json.loads(output.read_text(encoding="utf-8"))
    assert payload["quality"] == "medium"
    assert datetime.fromisoformat(payload["generated_at"]).tzinfo is not None
    assert {record["source_fetched_at"] for record in payload["records"]} == {
        fetched_at
    }
    assert [record["resolution"] for record in payload["records"]] == [
        "1080p",
        "2k",
        "4k",
    ]
    assert payload["records"][0] == {
        "cpu_id": "r5-5600",
        "gpu_id": "rtx-4060",
        "game_id": "cyberpunk-2077",
        "source_cpu_id": "1fB",
        "source_gpu_id": "1ge",
        "source_game_id": "02g",
        "source_url": EXPECTED_URL,
        "response_hash": "response-hash",
        "source_fetched_at": fetched_at,
        "resolution": "1080p",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "gpu",
        "bottleneck_percent": 5,
    }
    assert list(output.parent.glob(f".{output.name}.*.tmp")) == []


def test_import_fps_model_inputs_commits_one_reviewed_bundle(
    monkeypatch,
    tmp_path: Path,
    capsys,
) -> None:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'fps-model.sqlite3'}"
    input_path = tmp_path / "reviewed-fps.json"
    input_path.write_text(json.dumps(valid_document()), encoding="utf-8")
    monkeypatch.setenv("APP_POSTGRES_URL", database_url)
    engine = create_engine(database_url)
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="r7-9800x3d",
                    category="cpu",
                    name="R7 9800X3D",
                    brand="AMD",
                    detail_raw="AM5",
                    specs={},
                ),
                CatalogComponent(
                    id="rtx-4070",
                    category="gpu",
                    name="RTX 4070",
                    brand="NVIDIA",
                    detail_raw="12GB",
                    specs={},
                ),
            ],
        )

    invoke(monkeypatch, "import-fps-model-inputs", str(input_path))

    assert capsys.readouterr().out == (
        "Imported 2 reviewed hardware profiles and 1 reviewed FPS anchors.\n"
    )
    with Session(engine) as session:
        assert session.scalar(
            select(func.count()).select_from(HardwarePerformanceProfile)
        ) == 2
        assert session.scalar(
            select(func.count()).select_from(GamePerformanceAnchor)
        ) == 1
