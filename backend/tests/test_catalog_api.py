from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base, get_session
from app.main import create_app
from app.core.config import Settings


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


def test_lists_motherboards_compatible_with_cpu() -> None:
    client = make_client()

    response = client.get("/v1/catalog/motherboards", params={"cpu": "i5-14600k"})

    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == ["b760m"]
