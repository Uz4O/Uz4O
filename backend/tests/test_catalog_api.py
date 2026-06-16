from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.prices import ApprovedPriceRow
from app.catalog.repository import seed_component_prices, seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base, get_session
from app.main import create_app
from app.core.config import Settings
from datetime import datetime, timezone


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
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 Raptor Lake Refresh · LGA1700",
                    specs={"socket": "LGA1700"},
                ),
                CatalogComponent(
                    id="b760m",
                    category="motherboard",
                    name="B760M AORUS ELITE",
                    brand="技嘉",
                    detail_raw="Intel · LGA1700 · B760",
                    specs={"socket": "LGA1700", "chipset": "B760"},
                ),
                CatalogComponent(
                    id="b650m",
                    category="motherboard",
                    name="B650M MORTAR",
                    brand="微星",
                    detail_raw="AMD · AM5 · B650",
                    specs={"socket": "AM5", "chipset": "B650"},
                ),
            ],
        )
        seed_component_prices(
            session,
            [
                ApprovedPriceRow(
                    component_id="i5-14600k",
                    reference_price=1499,
                    price_range_low=1450,
                    price_range_high=1550,
                    accepted_count=4,
                    rejected_count=1,
                    review_reasons=["manual_check"],
                    source="approved-reference-prices.csv",
                    approved_at=datetime(2026, 6, 15, tzinfo=timezone.utc),
                )
            ],
        )

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_lists_catalog_components_with_filters() -> None:
    client = make_client()

    response = client.get("/v1/catalog/components", params={"category": "motherboard", "q": "B760"})

    assert response.status_code == 200
    assert response.json() == [
        {
            "id": "b760m",
            "category": "motherboard",
            "name": "B760M AORUS ELITE",
            "brand": "技嘉",
            "detail_raw": "Intel · LGA1700 · B760",
            "specs": {"socket": "LGA1700", "chipset": "B760"},
            "is_recommended": False,
            "status": "active",
        }
    ]


def test_catalog_components_support_bounded_pagination() -> None:
    client = make_client()

    response = client.get("/v1/catalog/components", params={"limit": 2, "offset": 0})

    assert response.status_code == 200
    assert len(response.json()) == 2

    invalid_limit = client.get("/v1/catalog/components", params={"limit": 501})
    invalid_offset = client.get("/v1/catalog/components", params={"offset": -1})

    assert invalid_limit.status_code == 422
    assert invalid_offset.status_code == 422


def test_lists_motherboards_compatible_with_cpu() -> None:
    client = make_client()

    response = client.get("/v1/catalog/motherboards", params={"cpu": "i5-14600k"})

    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == ["b760m"]


def test_lists_component_prices() -> None:
    client = make_client()

    response = client.get("/v1/catalog/prices")

    assert response.status_code == 200
    assert response.json() == [
        {
            "component_id": "i5-14600k",
            "reference_price": 1499,
            "price_range_low": 1450,
            "price_range_high": 1550,
            "source": "approved-reference-prices.csv",
            "accepted_count": 4,
            "rejected_count": 1,
            "review_reasons": ["manual_check"],
            "approved_at": "2026-06-15T00:00:00",
        }
    ]


def test_catalog_readiness_reports_missing_production_data() -> None:
    client = make_client()

    response = client.get("/v1/catalog/readiness")

    assert response.status_code == 200
    body = response.json()
    assert body["ready"] is False
    assert body["component_count"] == 3
    assert body["price_count"] == 1
    assert body["active_template_count"] == 0
    assert body["recommended_counts"] == {
        "cpu": 0,
        "gpu": 0,
        "motherboard": 0,
        "ram": 0,
        "storage": 0,
        "psu": 0,
    }
    assert body["missing_recommended_categories"] == [
        "cpu",
        "gpu",
        "motherboard",
        "ram",
        "storage",
        "psu",
    ]


def test_catalog_prices_reject_unbounded_public_limits() -> None:
    client = make_client()

    invalid_limit = client.get("/v1/catalog/prices", params={"limit": 501})
    invalid_offset = client.get("/v1/catalog/prices", params={"offset": -1})

    assert invalid_limit.status_code == 422
    assert invalid_offset.status_code == 422


def test_gets_component_price() -> None:
    client = make_client()

    response = client.get("/v1/catalog/components/i5-14600k/price")

    assert response.status_code == 200
    assert response.json()["reference_price"] == 1499


def test_returns_404_for_missing_component_price() -> None:
    client = make_client()

    response = client.get("/v1/catalog/components/b760m/price")

    assert response.status_code == 404
    assert response.json() == {"detail": "Component price not found"}
