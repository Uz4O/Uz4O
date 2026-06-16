from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


def make_client() -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="i7-14700f",
                    category="cpu",
                    name="i7-14700F",
                    brand="Intel",
                    detail_raw="14代 · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 219},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs={"tdp": 115, "perf_index": 72},
                ),
                CatalogComponent(
                    id="h610m",
                    category="motherboard",
                    name="H610M",
                    brand="华硕",
                    detail_raw="Intel · LGA1700 · H610",
                    specs={"socket": "LGA1700"},
                ),
                CatalogComponent(
                    id="psu-500w",
                    category="psu",
                    name="500W 电源",
                    brand="未知",
                    detail_raw="500W",
                    specs={"watt": 500},
                ),
                CatalogComponent(
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 · LGA1700",
                    specs={"perf_index": 78, "tdp": 125},
                ),
                CatalogComponent(
                    id="i5-10400f",
                    category="cpu",
                    name="i5-10400F",
                    brand="Intel",
                    detail_raw="10代 · LGA1200",
                    specs={"socket": "LGA1200", "perf_index": 55, "tdp": 65},
                ),
                CatalogComponent(
                    id="gtx-1660-super",
                    category="gpu",
                    name="GTX 1660 Super",
                    brand="NVIDIA",
                    detail_raw="6GB",
                    specs={"perf_index": 45, "tdp": 125},
                ),
                CatalogComponent(
                    id="b460m",
                    category="motherboard",
                    name="B460M Mortar",
                    brand="微星",
                    detail_raw="Intel · LGA1200 · B460",
                    specs={"socket": "LGA1200"},
                ),
                CatalogComponent(
                    id="psu-550w",
                    category="psu",
                    name="550W Gold",
                    brand="Corsair",
                    detail_raw="550W",
                    specs={"watt": 550},
                ),
            ],
        )
        session.get(HardwareComponent, "rtx-4060").is_recommended = True
        session.add(
            ComponentPrice(
                component_id="i7-14700f",
                reference_price=2100,
                price_range_low=2000,
                price_range_high=2300,
                source="manual",
                accepted_count=3,
                rejected_count=0,
                review_reasons=[],
                approved_at=datetime.now(timezone.utc),
            )
        )
        session.add(
            ComponentPrice(
                component_id="rtx-4060",
                reference_price=2200,
                price_range_low=2100,
                price_range_high=2400,
                source="manual",
                accepted_count=3,
                rejected_count=0,
                review_reasons=[],
                approved_at=datetime.now(timezone.utc),
            )
        )
        session.commit()

    app = create_app(
        Settings(
            _env_file=None,
            postgres_url=None,
            redis_url=None,
            response_cache_ttl_seconds=60,
            response_cache_max_entries=20,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_review_analyze_reuses_cached_response_for_identical_input() -> None:
    client = make_client()
    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}

    first = client.post("/v1/review/analyze", json=payload)
    second = client.post("/v1/review/analyze", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.headers["x-cache"] == "MISS"
    assert second.headers["x-cache"] == "HIT"
    assert second.json() == first.json()


def test_review_analyze_cache_key_includes_input_payload() -> None:
    client = make_client()

    first = client.post(
        "/v1/review/analyze",
        json={"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"},
    )
    different = client.post(
        "/v1/review/analyze",
        json={"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 5999"},
    )

    assert first.status_code == 200
    assert different.status_code == 200
    assert first.headers["x-cache"] == "MISS"
    assert different.headers["x-cache"] == "MISS"


def test_perf_estimate_reuses_cached_response_for_identical_input() -> None:
    client = make_client()
    payload = {
        "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
        "resolution": "2k",
        "games": ["CS2"],
    }

    first = client.post("/v1/perf/estimate", json=payload)
    second = client.post("/v1/perf/estimate", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.headers["x-cache"] == "MISS"
    assert second.headers["x-cache"] == "HIT"
    assert second.json() == first.json()


def test_upgrade_plan_reuses_cached_response_for_identical_input() -> None:
    client = make_client()
    payload = {
        "budget": 3000,
        "need": "提升游戏性能",
        "games": ["CS2"],
        "current": {
            "cpu": "i5-10400f",
            "gpu": "gtx-1660-super",
            "motherboard": "b460m",
            "psu": "psu-550w",
        },
    }

    first = client.post("/v1/upgrade/plan", json=payload)
    second = client.post("/v1/upgrade/plan", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.headers["x-cache"] == "MISS"
    assert second.headers["x-cache"] == "HIT"
    assert second.json() == first.json()
