from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
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
