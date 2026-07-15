import json
from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base
from app.perf.anchor_repository import (
    replace_active_calibration,
    upsert_game_performance_anchors,
    upsert_hardware_performance_profiles,
)
from app.perf.calibration import calibrate_available_models
from app.perf.models import (
    GamePerformanceAnchor,
    GamePerformanceCalibration,
    HardwarePerformanceProfile,
)
from app.perf.readiness import build_estimator_readiness, write_estimator_readiness


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
                    id="cpu-low",
                    category="cpu",
                    name="CPU Low",
                    brand="Test",
                    detail_raw="",
                    specs={},
                ),
                CatalogComponent(
                    id="cpu-high",
                    category="cpu",
                    name="CPU High",
                    brand="Test",
                    detail_raw="",
                    specs={},
                ),
                CatalogComponent(
                    id="gpu-low",
                    category="gpu",
                    name="GPU Low",
                    brand="Test",
                    detail_raw="",
                    specs={},
                ),
                CatalogComponent(
                    id="gpu-high",
                    category="gpu",
                    name="GPU High",
                    brand="Test",
                    detail_raw="",
                    specs={},
                ),
            ],
        )
        yield value


def profile(component_id, category, score, *, is_common=True):
    return HardwarePerformanceProfile(
        component_id=component_id,
        category=category,
        performance_score=score,
        is_common=is_common,
        supports_dlss=category == "gpu",
        supports_fsr=category == "gpu",
        supports_standard_frame_generation=category == "gpu",
        source_kind="self_measured",
        source_reference="test-fixture",
        reviewed_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
        import_batch="model-v1",
    )


def anchor(axis, cpu_id, gpu_id, fps, *, role="fit"):
    return GamePerformanceAnchor(
        game_id="cyberpunk-2077",
        axis=axis,
        cpu_id=cpu_id,
        gpu_id=gpu_id,
        resolution="2k",
        render_mode="dlss_quality_fg",
        average_fps=fps,
        sample_role=role,
        game_version="2.31",
        driver_version=f"driver-{cpu_id}-{gpu_id}",
        source_kind="self_measured",
        source_reference="test-fixture",
        tested_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
        import_batch="model-v1",
    )


def seed_cyberpunk_model_inputs(session) -> None:
    upsert_hardware_performance_profiles(
        session,
        [
            profile("cpu-low", "cpu", 50),
            profile("cpu-high", "cpu", 100),
            profile("gpu-low", "gpu", 50),
            profile("gpu-high", "gpu", 100),
        ],
    )
    upsert_game_performance_anchors(
        session,
        [
            anchor("cpu", "cpu-low", "gpu-high", 100),
            anchor("cpu", "cpu-high", "gpu-high", 200),
            anchor("gpu", "cpu-high", "gpu-low", 90),
            anchor("gpu", "cpu-high", "gpu-high", 180),
            anchor("cross", "cpu-low", "gpu-low", 90, role="validation"),
            anchor("cross", "cpu-high", "gpu-high", 175, role="validation"),
        ],
    )


def seed_ready_cyberpunk_model(session) -> None:
    seed_cyberpunk_model_inputs(session)
    replace_active_calibration(
        session,
        GamePerformanceCalibration(
            game_id="cyberpunk-2077",
            resolution="2k",
            render_mode="dlss_quality_fg",
            model_version="model-v1",
            correction_factor=0.98,
            validation_mape=4.0,
            validation_count=2,
            common_validation_mape=4.0,
            common_validation_count=2,
            is_active=False,
            calibrated_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
        ),
    )


def test_calibration_activates_only_a_model_that_passes_the_gate(session) -> None:
    seed_cyberpunk_model_inputs(session)

    summary = calibrate_available_models(session, "model-v1")

    assert summary.evaluated_count == 1
    assert summary.activated_count == 1
    readiness = build_estimator_readiness(session)
    assert readiness.models["cyberpunk-2077/2k/dlss_quality_fg"].ready is True


def test_calibration_keeps_high_error_model_inactive(session) -> None:
    seed_cyberpunk_model_inputs(session)
    validation_rows = list(
        row
        for row in session.query(GamePerformanceAnchor)
        if row.sample_role == "validation"
    )
    validation_rows[0].average_fps = 40
    validation_rows[1].average_fps = 180

    summary = calibrate_available_models(session, "model-v1")

    assert summary.evaluated_count == 1
    assert summary.activated_count == 0
    readiness = build_estimator_readiness(session)
    assert readiness.models["cyberpunk-2077/2k/dlss_quality_fg"].ready is False


def test_readiness_rejects_non_monotonic_active_fit_points(session) -> None:
    seed_ready_cyberpunk_model(session)
    cpu_rows = [
        row
        for row in session.query(GamePerformanceAnchor)
        if row.axis == "cpu"
    ]
    cpu_rows[0].average_fps = 200
    cpu_rows[1].average_fps = 100
    session.flush()

    readiness = build_estimator_readiness(session)

    model = readiness.models["cyberpunk-2077/2k/dlss_quality_fg"]
    assert model.ready is False
    assert "cpu_fit_monotonicity" in model.reasons


def test_readiness_reports_ready_model_but_blocks_incomplete_release(session) -> None:
    seed_ready_cyberpunk_model(session)

    readiness = build_estimator_readiness(session)

    model = readiness.models["cyberpunk-2077/2k/dlss_quality_fg"]
    assert model.ready is True
    assert model.validation_share == pytest.approx(2 / 6)
    assert readiness.ready is False
    assert "cyberpunk-2077/1080p/dlss_quality_fg" in readiness.missing_models


def test_readiness_requires_all_catalog_hardware_profiles(session) -> None:
    upsert_hardware_performance_profiles(
        session,
        [profile("cpu-low", "cpu", 50)],
    )

    readiness = build_estimator_readiness(session)

    assert readiness.ready is False
    assert readiness.missing_hardware_profiles == [
        "cpu-high",
        "gpu-high",
        "gpu-low",
    ]


def test_readiness_report_is_written_atomically(session, tmp_path) -> None:
    output = tmp_path / "nested/readiness.json"

    readiness = build_estimator_readiness(session)
    write_estimator_readiness(readiness, output)

    document = json.loads(output.read_text(encoding="utf-8"))
    assert document["ready"] is False
    assert document["required_model_count"] == 45
    assert list(output.parent.glob(f".{output.name}.*.tmp")) == []
