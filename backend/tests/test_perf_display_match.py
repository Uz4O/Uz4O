from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base
from app.perf.service import DisplayMatchRequest, build_display_match


def make_session() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = Session(engine)
    seed_hardware_components(session, [
        CatalogComponent(
            id="r7-9800x3d", category="cpu", name="R7 9800X3D", brand="AMD",
            detail_raw="", specs={"perf_index": 100}
        ),
        CatalogComponent(
            id="rtx-5070", category="gpu", name="RTX 5070", brand="NVIDIA",
            detail_raw="", specs={}
        )
    ])
    session.commit()
    return session


def test_gpu_and_3a_games_recommend_2k_high_refresh_spec() -> None:
    with make_session() as session:
        result = build_display_match(
            session,
            DisplayMatchRequest(cpu_id="r7-9800x3d", gpu_id="rtx-5070", games=["cyberpunk-2077"]),
        )

    assert result.resolution == "2k"
    assert result.refresh_rate == 165
    assert result.size == "27 英寸"
    assert result.panel == "Fast IPS"


def test_esports_games_prioritize_1080p_high_refresh() -> None:
    with make_session() as session:
        result = build_display_match(
            session,
            DisplayMatchRequest(cpu_id="r7-9800x3d", gpu_id="rtx-5070", games=["valorant", "cs2"]),
        )

    assert result.resolution == "1080p"
    assert result.refresh_rate == 240
    assert result.size == "24 英寸"
