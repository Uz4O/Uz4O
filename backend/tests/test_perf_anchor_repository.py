from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base
from app.perf.anchor_repository import (
    get_active_calibration,
    get_hardware_performance_profiles,
    list_axis_anchors,
    list_validation_anchors,
    replace_active_calibration,
    upsert_game_performance_anchors,
    upsert_hardware_performance_profiles,
)
from app.perf.models import (
    GamePerformanceAnchor,
    GamePerformanceCalibration,
    HardwarePerformanceProfile,
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
                    id="r7-9800x3d",
                    category="cpu",
                    name="R7 9800X3D",
                    brand="AMD",
                    detail_raw="AM5",
                    specs={},
                ),
                CatalogComponent(
                    id="r5-5600",
                    category="cpu",
                    name="R5 5600",
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
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs={},
                ),
            ],
        )
        yield value


def hardware_profile(**overrides) -> HardwarePerformanceProfile:
    values = {
        "component_id": "rtx-4070",
        "category": "gpu",
        "performance_score": 100,
        "is_common": True,
        "supports_dlss": True,
        "supports_fsr": True,
        "supports_standard_frame_generation": True,
        "source_kind": "self_measured",
        "source_reference": "lab-20260715",
        "reviewed_at": datetime(2026, 7, 15, tzinfo=timezone.utc),
        "import_batch": "test",
    }
    values.update(overrides)
    return HardwarePerformanceProfile(**values)


def anchor(**overrides) -> GamePerformanceAnchor:
    values = {
        "game_id": "cyberpunk-2077",
        "axis": "gpu",
        "cpu_id": "r7-9800x3d",
        "gpu_id": "rtx-4070",
        "resolution": "2k",
        "render_mode": "dlss_quality_fg",
        "average_fps": 105,
        "sample_role": "fit",
        "game_version": "2.31",
        "driver_version": "reviewed",
        "source_kind": "self_measured",
        "source_reference": "lab-20260715",
        "tested_at": datetime(2026, 7, 15, tzinfo=timezone.utc),
        "import_batch": "test",
    }
    values.update(overrides)
    return GamePerformanceAnchor(**values)


def calibration(**overrides) -> GamePerformanceCalibration:
    values = {
        "game_id": "cyberpunk-2077",
        "resolution": "2k",
        "render_mode": "dlss_quality_fg",
        "model_version": "2026-07-15-v1",
        "correction_factor": 0.97,
        "validation_mape": 7.5,
        "validation_count": 5,
        "common_validation_mape": 6.0,
        "common_validation_count": 3,
        "is_active": False,
        "calibrated_at": datetime(2026, 7, 15, tzinfo=timezone.utc),
    }
    values.update(overrides)
    return GamePerformanceCalibration(**values)


def test_hardware_profile_and_anchor_round_trip(session) -> None:
    profile = hardware_profile()
    row = anchor()

    assert upsert_hardware_performance_profiles(session, [profile]) == 1
    assert upsert_game_performance_anchors(session, [row]) == 1
    assert upsert_game_performance_anchors(session, [anchor()]) == 1

    stored_profile = get_hardware_performance_profiles(session, ["rtx-4070"])
    assert stored_profile["rtx-4070"].performance_score == 100
    stored_anchors = list_axis_anchors(
        session,
        "cyberpunk-2077",
        "2k",
        "dlss_quality_fg",
        "gpu",
    )
    assert len(stored_anchors) == 1
    assert stored_anchors[0].average_fps == 105


def test_upserts_skip_older_reviewed_values_and_normalize_utc(session) -> None:
    local_time = datetime(2026, 7, 15, 8, tzinfo=timezone(timedelta(hours=8)))
    older = datetime(2026, 7, 14, tzinfo=timezone.utc)

    assert upsert_hardware_performance_profiles(
        session,
        [hardware_profile(performance_score=100, reviewed_at=local_time)],
    ) == 1
    assert upsert_hardware_performance_profiles(
        session,
        [hardware_profile(performance_score=50, reviewed_at=older)],
    ) == 0
    assert upsert_game_performance_anchors(
        session,
        [anchor(average_fps=105, tested_at=local_time)],
    ) == 1
    assert upsert_game_performance_anchors(
        session,
        [anchor(average_fps=20, tested_at=older)],
    ) == 0

    profile = get_hardware_performance_profiles(session, ["rtx-4070"])["rtx-4070"]
    stored_anchor = list_axis_anchors(
        session,
        "cyberpunk-2077",
        "2k",
        "dlss_quality_fg",
        "gpu",
    )[0]
    assert profile.performance_score == 100
    assert stored_anchor.average_fps == 105


def test_validation_rows_are_separate_and_active_calibration_is_replaced(session) -> None:
    validation = anchor(axis="cross", sample_role="validation")
    upsert_game_performance_anchors(session, [validation])
    first = calibration()
    second = calibration(
        model_version="2026-07-15-v2",
        correction_factor=0.95,
    )

    replace_active_calibration(session, first)
    replace_active_calibration(session, second)

    assert list_validation_anchors(
        session,
        "cyberpunk-2077",
        "2k",
        "dlss_quality_fg",
    ) == [validation]
    active = get_active_calibration(
        session,
        "cyberpunk-2077",
        "2k",
        "dlss_quality_fg",
    )
    assert active is not None
    assert active.model_version == "2026-07-15-v2"
    assert active.correction_factor == 0.95


@pytest.mark.parametrize(
    "row",
    [
        hardware_profile(category="cpu", supports_dlss=True),
        hardware_profile(performance_score=0),
        anchor(axis="unknown"),
        anchor(resolution="720p"),
        anchor(render_mode="ray_tracing"),
        anchor(average_fps=0),
        anchor(axis="cross", sample_role="fit"),
        anchor(source_kind="unknown"),
        calibration(correction_factor=2.0),
        calibration(common_validation_count=6),
    ],
)
def test_database_rejects_invalid_estimator_rows(session, row) -> None:
    session.add(row)
    with pytest.raises(IntegrityError):
        session.commit()
