from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base
from app.perf.importer import PerformanceEstimateInput
from app.perf.models import GamePerformanceEstimate
from app.perf.repository import (
    get_performance_estimates,
    upsert_performance_estimates,
)


@pytest.fixture
def session():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine) as value:
        seed_hardware_components(
            value,
            [
                CatalogComponent(
                    id="r5-5600",
                    category="cpu",
                    name="R5 5600",
                    brand="AMD",
                    detail_raw="AM4",
                    specs={},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs={},
                ),
                CatalogComponent(
                    id="r5-5600x",
                    category="cpu",
                    name="R5 5600X",
                    brand="AMD",
                    detail_raw="AM4",
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
        yield value


def estimate_input(**overrides):
    payload = {
        "cpu_id": "r5-5600",
        "gpu_id": "rtx-4060",
        "game_id": "cyberpunk-2077",
        "resolution": "1080p",
        "quality": "medium",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "cpu",
        "bottleneck_percent": 11,
        "source_url": "https://pc-builds.com/example",
        "source_fetched_at": datetime(2026, 7, 12, tzinfo=timezone.utc),
        "import_batch": "test",
    }
    payload.update(overrides)
    return PerformanceEstimateInput(**payload)


def test_upsert_is_idempotent_and_exact_lookup_is_scoped_by_quality(session) -> None:
    rows = [
        estimate_input(),
        estimate_input(resolution="2k"),
        estimate_input(game_id="black-myth-wukong"),
        estimate_input(cpu_id="r5-5600x"),
        estimate_input(gpu_id="rtx-4070"),
    ]

    assert upsert_performance_estimates(session, rows) == 5
    assert upsert_performance_estimates(
        session,
        [estimate_input(average_fps=79)],
    ) == 1

    result = get_performance_estimates(
        session,
        "r5-5600",
        "rtx-4060",
        ["cyberpunk-2077"],
        "1080p",
        "medium",
    )
    assert len(result) == 1
    assert result[0].average_fps == 79
    assert (
        get_performance_estimates(
            session,
            "r5-5600",
            "rtx-4060",
            ["cyberpunk-2077"],
            "1080p",
            "high",
        )
        == []
    )


def test_upsert_prefetches_existing_rows_in_bounded_chunks(session) -> None:
    estimates = [
        estimate_input(game_id=f"game-{index}")
        for index in range(2400)
    ]
    select_count = 0

    def count_selects(connection, cursor, statement, parameters, context, executemany):
        nonlocal select_count
        if statement.lstrip().upper().startswith("SELECT"):
            select_count += 1

    engine = session.get_bind()
    event.listen(engine, "before_cursor_execute", count_selects)
    try:
        assert upsert_performance_estimates(session, estimates) == 2400
    finally:
        event.remove(engine, "before_cursor_execute", count_selects)

    assert select_count == 16


def test_upsert_skips_older_source_rows_and_counts_only_written_rows(session) -> None:
    newer = datetime(2026, 7, 13, tzinfo=timezone.utc)
    older = datetime(2026, 7, 12, tzinfo=timezone.utc)

    assert upsert_performance_estimates(
        session,
        [estimate_input(average_fps=80, maximum_fps=100, source_fetched_at=newer)],
    ) == 1
    assert upsert_performance_estimates(
        session,
        [estimate_input(average_fps=70, maximum_fps=100, source_fetched_at=older)],
    ) == 0

    stored = get_performance_estimates(
        session,
        "r5-5600",
        "rtx-4060",
        ["cyberpunk-2077"],
        "1080p",
        "medium",
    )[0]
    assert stored.average_fps == 80
    assert stored.source_fetched_at.replace(tzinfo=timezone.utc) == newer


def test_upsert_normalizes_source_time_to_utc_before_sqlite_persistence(session) -> None:
    local_time = datetime(
        2026,
        7,
        12,
        8,
        tzinfo=timezone(timedelta(hours=8)),
    )
    newer_utc = datetime(2026, 7, 12, 1, tzinfo=timezone.utc)

    assert upsert_performance_estimates(
        session,
        [estimate_input(average_fps=70, source_fetched_at=local_time)],
    ) == 1
    session.expunge_all()
    first_stored = get_performance_estimates(
        session,
        "r5-5600",
        "rtx-4060",
        ["cyberpunk-2077"],
        "1080p",
        "medium",
    )[0]
    assert first_stored.source_fetched_at.replace(tzinfo=timezone.utc) == datetime(
        2026,
        7,
        12,
        tzinfo=timezone.utc,
    )
    session.expunge_all()
    assert upsert_performance_estimates(
        session,
        [estimate_input(average_fps=80, source_fetched_at=newer_utc)],
    ) == 1

    stored = get_performance_estimates(
        session,
        "r5-5600",
        "rtx-4060",
        ["cyberpunk-2077"],
        "1080p",
        "medium",
    )[0]
    assert stored.average_fps == 80
    assert stored.source_fetched_at.replace(tzinfo=timezone.utc) == newer_utc


def test_chunk_failure_does_not_commit_prior_chunks(session) -> None:
    estimates = [
        estimate_input(game_id=f"game-{index}")
        for index in range(150)
    ]
    estimates.append(estimate_input(game_id="invalid", quality="high"))

    with pytest.raises(IntegrityError):
        upsert_performance_estimates(session, estimates)
    session.rollback()

    assert session.scalar(
        select(func.count()).select_from(GamePerformanceEstimate)
    ) == 0


@pytest.mark.parametrize(
    "overrides",
    [
        {"minimum_fps": 90, "average_fps": 80},
        {"resolution": "720p"},
        {"quality": "high"},
    ],
)
def test_database_rejects_invalid_performance_rows(session, overrides) -> None:
    session.add(GamePerformanceEstimate(**vars(estimate_input(**overrides))))

    with pytest.raises(IntegrityError):
        session.commit()


def test_cpu_and_gpu_reference_hardware_components() -> None:
    table = GamePerformanceEstimate.__table__

    assert {str(key.column) for key in table.c.cpu_id.foreign_keys} == {
        "hardware_component.id"
    }
    assert {str(key.column) for key in table.c.gpu_id.foreign_keys} == {
        "hardware_component.id"
    }
