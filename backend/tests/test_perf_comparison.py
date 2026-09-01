from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.perf.service import (
    PerformanceComparisonRequest,
    compare_performance,
    performance_ladder,
)
from app.perf.valorant_reference import CPU_TIER_LIST
from app.db import Base


def make_session() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add_all(
        [
            HardwareComponent(
                id="rtx-5090", category="gpu", name="RTX 5090", brand="NVIDIA", detail_raw="", specs={}
            ),
            HardwareComponent(
                id="rtx-5080", category="gpu", name="RTX 5080", brand="NVIDIA", detail_raw="", specs={}
            ),
            HardwareComponent(
                id="rtx-5090-d", category="gpu", name="RTX 5090 D", brand="NVIDIA", detail_raw="", specs={}
            ),
            HardwareComponent(
                id="r7-9800x3d", category="cpu", name="R7 9800X3D", brand="AMD", detail_raw="", specs={}
            ),
            HardwareComponent(
                id="i5-12400f", category="cpu", name="i5-12400F", brand="Intel", detail_raw="", specs={}
            ),
        ]
    )
    session.commit()
    return session


def test_gpu_comparison_uses_unified_5090_reference_and_relative_delta() -> None:
    with make_session() as session:
        result = compare_performance(
            session,
            PerformanceComparisonRequest(
                category="gpu", left_id="rtx-5090", right_id="rtx-5080"
            ),
        )

    assert result.left.relative_percent == 100.0
    assert result.right.relative_percent == 69.5
    assert result.stronger_by_percent == 44.0
    assert result.summary == "RTX 5090 比 RTX 5080 强 44.0%"


def test_gpu_comparison_treats_5090_and_5090_d_as_equal() -> None:
    with make_session() as session:
        result = compare_performance(
            session,
            PerformanceComparisonRequest(
                category="gpu", left_id="rtx-5090", right_id="rtx-5090-d"
            ),
        )

    assert result.left.relative_percent == 100.0
    assert result.right.relative_percent == 100.0
    assert result.stronger_by_percent == 0
    assert result.summary == "两者性能相当"


def test_gpu_ladder_is_flat_and_ranked_by_relative_percent() -> None:
    with make_session() as session:
        result = performance_ladder(session, "gpu")

    assert [(item.rank, item.id, item.relative_percent) for item in result.items] == [
        (1, "rtx-5090", 100.0),
        (2, "rtx-5090-d", 100.0),
        (3, "rtx-5080", 69.5),
    ]


def test_cpu_comparison_uses_valorant_average_fps() -> None:
    with make_session() as session:
        result = compare_performance(
            session,
            PerformanceComparisonRequest(
                category="cpu", left_id="r7-9800x3d", right_id="i5-12400f"
            ),
        )

    assert result.benchmark == "valorant"
    assert result.left.benchmark_score == 710.0
    assert result.left.relative_percent == 100.0
    assert result.stronger_by_percent == 146.5


def test_cpu_ladder_uses_complete_truebottleneck_snapshot() -> None:
    with make_session() as session:
        result = performance_ladder(session, "cpu")

    assert len(result.items) == len(CPU_TIER_LIST) == 110
    assert result.benchmark == "truebottleneck"
    assert (result.items[0].id, result.items[0].relative_percent) == (
        "r7-9850x3d",
        100.0,
    )
    assert result.items[-1].id == "i5-4460"
