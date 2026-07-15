import json
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app
from app.perf.anchor_repository import (
    replace_active_calibration,
    upsert_game_performance_anchors,
    upsert_hardware_performance_profiles,
)
from app.perf.models import (
    GamePerformanceAnchor,
    GamePerformanceCalibration,
    GamePerformanceEstimate,
    HardwarePerformanceProfile,
)
from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GPUCapabilities,
    render_mode_for,
)


APPROVED_GAME_IDS = list(APPROVED_GAME_PROFILES)
NOW = datetime(2026, 7, 15, tzinfo=timezone.utc)


def catalog_component(component_id: str, category: str) -> CatalogComponent:
    return CatalogComponent(
        id=component_id,
        category=category,
        name=component_id,
        brand="Test",
        detail_raw="",
        specs={"perf_index": 100 if category == "cpu" else 40},
    )


def hardware_profile(
    component_id: str,
    category: str,
    score: int,
    *,
    supports_fg: bool = True,
) -> HardwarePerformanceProfile:
    return HardwarePerformanceProfile(
        component_id=component_id,
        category=category,
        performance_score=score,
        is_common=True,
        supports_dlss=category == "gpu",
        supports_fsr=category == "gpu",
        supports_standard_frame_generation=category == "gpu" and supports_fg,
        source_kind="self_measured",
        source_reference="test-fixture",
        reviewed_at=NOW,
        import_batch="model-v1",
    )


def model_anchor(
    game_id: str,
    render_mode: str,
    axis: str,
    cpu_id: str,
    gpu_id: str,
    average_fps: int,
    *,
    role: str = "fit",
) -> GamePerformanceAnchor:
    return GamePerformanceAnchor(
        game_id=game_id,
        axis=axis,
        cpu_id=cpu_id,
        gpu_id=gpu_id,
        resolution="2k",
        render_mode=render_mode,
        average_fps=average_fps,
        sample_role=role,
        game_version="test-version",
        driver_version=f"{axis}-{cpu_id}-{gpu_id}",
        source_kind="self_measured",
        source_reference="test-fixture",
        tested_at=NOW,
        import_batch="model-v1",
    )


def seed_active_model(
    session: Session,
    game_id: str,
    *,
    render_mode: str = "",
    cpu_fps=(120, 220),
    gpu_fps=(90, 180),
    correction_factor=0.95,
) -> None:
    mode = render_mode or render_mode_for(
        APPROVED_GAME_PROFILES[game_id],
        GPUCapabilities(True, True, True),
    ).value
    upsert_game_performance_anchors(
        session,
        [
            model_anchor(game_id, mode, "cpu", "cpu-low", "gpu-high", cpu_fps[0]),
            model_anchor(game_id, mode, "cpu", "cpu-high", "gpu-high", cpu_fps[1]),
            model_anchor(game_id, mode, "gpu", "cpu-high", "gpu-low", gpu_fps[0]),
            model_anchor(game_id, mode, "gpu", "cpu-high", "gpu-high", gpu_fps[1]),
            model_anchor(
                game_id,
                mode,
                "cross",
                "cpu-low",
                "gpu-low",
                min(cpu_fps[0], gpu_fps[0]),
                role="validation",
            ),
        ],
    )
    replace_active_calibration(
        session,
        GamePerformanceCalibration(
            game_id=game_id,
            resolution="2k",
            render_mode=mode,
            model_version="model-v1",
            correction_factor=correction_factor,
            validation_mape=5.0,
            validation_count=1,
            common_validation_mape=5.0,
            common_validation_count=1,
            is_active=False,
            calibrated_at=NOW,
        ),
    )


def make_client(
    games=(),
    *,
    include_profiles=True,
    setup=None,
) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    with Session(engine) as session:
        components = [
            catalog_component("cpu-low", "cpu"),
            catalog_component("cpu-mid", "cpu"),
            catalog_component("cpu-high", "cpu"),
            catalog_component("gpu-low", "gpu"),
            catalog_component("gpu-mid", "gpu"),
            catalog_component("gpu-no-fg", "gpu"),
            catalog_component("gpu-high", "gpu"),
        ]
        seed_hardware_components(session, components)
        if include_profiles:
            upsert_hardware_performance_profiles(
                session,
                [
                    hardware_profile("cpu-low", "cpu", 50),
                    hardware_profile("cpu-mid", "cpu", 75),
                    hardware_profile("cpu-high", "cpu", 100),
                    hardware_profile("gpu-low", "gpu", 40),
                    hardware_profile("gpu-mid", "gpu", 60),
                    hardware_profile("gpu-no-fg", "gpu", 60, supports_fg=False),
                    hardware_profile("gpu-high", "gpu", 80),
                ],
            )
        for game_id in games:
            seed_active_model(session, game_id)
        if setup is not None:
            setup(session)
        session.commit()

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def post_estimate(
    client: TestClient,
    games,
    *,
    cpu="cpu-mid",
    gpu="gpu-mid",
    resolution="2k",
):
    return client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": cpu, "gpu": gpu},
            "resolution": resolution,
            "games": games,
        },
    )


def test_ready_response_contains_average_fps_only() -> None:
    client = make_client(["cyberpunk-2077"])

    response = post_estimate(client, ["cyberpunk-2077"])

    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "average_fps": 128,
        "advice": "高画质，支持时开启质量档超分和标准帧生成。",
        "missing_data": [],
        "missing_games": [],
        "game_results": [
            {"game": "cyberpunk-2077", "average_fps": 128}
        ],
    }


def test_multi_game_average_keeps_requested_order_with_ai_fallback() -> None:
    def setup(session):
        seed_active_model(
            session,
            "valorant",
            cpu_fps=(70, 170),
            gpu_fps=(200, 300),
            correction_factor=1.0,
        )

    client = make_client(["cyberpunk-2077"], setup=setup)

    ready = post_estimate(client, ["valorant", "cyberpunk-2077"]).json()
    fallback = post_estimate(client, ["cyberpunk-2077", "cs2"]).json()

    assert ready["average_fps"] == 124
    assert [row["game"] for row in ready["game_results"]] == [
        "valorant",
        "cyberpunk-2077",
    ]
    assert fallback["status"] == "ready"
    assert fallback["missing_games"] == []
    assert [row["game"] for row in fallback["game_results"]] == [
        "cyberpunk-2077",
        "cs2",
    ]


def test_elden_ring_result_is_capped_at_60_fps() -> None:
    def setup(session):
        seed_active_model(
            session,
            "elden-ring",
            cpu_fps=(100, 300),
            gpu_fps=(100, 300),
            correction_factor=1.0,
        )

    body = post_estimate(make_client(setup=setup), ["elden-ring"]).json()

    assert body["average_fps"] == 60


def test_render_mode_falls_back_when_gpu_does_not_support_frame_generation() -> None:
    def setup(session):
        seed_active_model(
            session,
            "cyberpunk-2077",
            render_mode="dlss_quality",
            cpu_fps=(100, 200),
            gpu_fps=(60, 120),
            correction_factor=1.0,
        )

    body = post_estimate(
        make_client(setup=setup),
        ["cyberpunk-2077"],
        gpu="gpu-no-fg",
    ).json()

    assert body["average_fps"] == 90


def test_all_games_expands_the_approved_15_game_scope() -> None:
    body = post_estimate(
        make_client(APPROVED_GAME_IDS),
        ["all-games"],
    ).json()

    assert body["status"] == "ready"
    assert [row["game"] for row in body["game_results"]] == APPROVED_GAME_IDS


def test_unknown_hardware_or_game_is_rejected() -> None:
    client = make_client()

    assert post_estimate(client, ["cs2"], cpu="unknown").status_code == 422
    assert post_estimate(client, ["unknown-game"]).status_code == 422
    assert post_estimate(client, ["cs2"], cpu="gpu-mid").status_code == 422


def test_missing_profile_or_inactive_model_uses_ai_fallback() -> None:
    missing_profile = post_estimate(
        make_client(include_profiles=False),
        ["cs2"],
    ).json()
    inactive_model = post_estimate(make_client(), ["cs2"]).json()

    assert missing_profile["status"] == "ready"
    assert missing_profile["average_fps"] == 210
    assert missing_profile["missing_data"] == []
    assert inactive_model["status"] == "ready"
    assert inactive_model["average_fps"] == 210
    assert inactive_model["advice"].startswith("平均帧为 AI 估算值")


def test_pc_builds_exact_rows_are_used_before_the_model() -> None:
    def setup(session):
        session.add(
            GamePerformanceEstimate(
                cpu_id="cpu-mid",
                gpu_id="gpu-mid",
                game_id="cyberpunk-2077",
                resolution="2k",
                quality="medium",
                average_fps=999,
                minimum_fps=999,
                maximum_fps=999,
                bottleneck_type=None,
                bottleneck_percent=None,
                source_url="https://pc-builds.com/zh/fps-calculator/result/example",
                source_fetched_at=NOW,
                import_batch="pc-builds-reference",
            )
        )

    body = post_estimate(
        make_client(["cyberpunk-2077"], setup=setup),
        ["cyberpunk-2077"],
    ).json()

    assert body["status"] == "ready"
    assert body["average_fps"] == 999
    assert body["game_results"] == [
        {"game": "cyberpunk-2077", "average_fps": 999}
    ]
    assert body["advice"] == "第三方网站中等画质估算，实际帧数会因游戏设置和版本变化。"


def test_request_limits_and_sse_result_use_the_average_only_shape() -> None:
    client = make_client(["cs2"])
    assert post_estimate(client, APPROVED_GAME_IDS).status_code == 200
    assert post_estimate(client, APPROVED_GAME_IDS + ["extra"]).status_code == 422

    response = client.post(
        "/v1/perf/estimate/stream",
        json={
            "hardware": {"cpu": "cpu-mid", "gpu": "gpu-mid"},
            "resolution": "2k",
            "games": ["cs2"],
        },
    )
    events = _sse_events(response.text)

    assert [event["event"] for event in events] == [
        "progress",
        "progress",
        "cache",
        "result",
    ]
    assert set(events[-1]["data"]) == {
        "status",
        "average_fps",
        "advice",
        "missing_data",
        "missing_games",
        "game_results",
    }


def _sse_events(raw: str):
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(
            line.removeprefix("event: ")
            for line in lines
            if line.startswith("event: ")
        )
        data = next(
            line.removeprefix("data: ")
            for line in lines
            if line.startswith("data: ")
        )
        events.append({"event": event_name, "data": json.loads(data)})
    return events
