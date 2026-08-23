from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

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
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 Raptor Lake Refresh · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 120},
                ),
                CatalogComponent(
                    id="rtx-5070",
                    category="gpu",
                    name="RTX 5070",
                    brand="NVIDIA",
                    detail_raw="250W",
                    specs={"tdp": 250},
                ),
                CatalogComponent(
                    id="b760m",
                    category="motherboard",
                    name="B760M AORUS ELITE",
                    brand="技嘉",
                    detail_raw="Intel · LGA1700 · B760",
                    specs={"socket": "LGA1700"},
                ),
                CatalogComponent(
                    id="b650m",
                    category="motherboard",
                    name="B650M MORTAR",
                    brand="微星",
                    detail_raw="AMD · AM5 · B650",
                    specs={"socket": "AM5"},
                ),
                CatalogComponent(
                    id="ram-ddr5",
                    category="ram",
                    name="DDR5 32GB",
                    brand="芝奇",
                    detail_raw="DDR5 · 32GB",
                    specs={"type": "DDR5"},
                ),
                CatalogComponent(
                    id="psu-750w",
                    category="psu",
                    name="750W Gold",
                    brand="Corsair",
                    detail_raw="750W · 80+ Gold",
                    specs={"watt": 750},
                ),
            ],
        )

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_compat_check_returns_pass_for_basic_compatible_build() -> None:
    client = make_client()

    response = client.post(
        "/v1/compat/check",
        json={
            "components": {
                "cpu": "i5-14600k",
                "motherboard": "b760m",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["compatible"] is True
    assert body["summary"] == "这套配置没有发现硬性兼容问题。"
    assert body["finding_counts"]["error"] == 0
    assert "cpu_motherboard_socket" in body["checked_rule_codes"]
    assert any(finding["code"] == "cpu_motherboard_socket" for finding in body["findings"])


def test_compat_check_returns_error_for_socket_mismatch() -> None:
    client = make_client()

    response = client.post(
        "/v1/compat/check",
        json={
            "components": {
                "cpu": "i5-14600k",
                "motherboard": "b650m",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["compatible"] is False
    assert any(
        finding["code"] == "cpu_motherboard_socket" and finding["level"] == "error"
        for finding in body["findings"]
    )


def test_compat_check_rejects_oversized_selection() -> None:
    client = make_client()

    response = client.post(
        "/v1/compat/check",
        json={"components": {f"role-{index}": f"component-{index}" for index in range(80)}},
    )

    assert response.status_code == 422


def test_compat_check_returns_recommended_psu_watt_for_partial_diy_selection() -> None:
    client = make_client()

    response = client.post(
        "/v1/compat/check",
        json={"components": {"cpu": "i5-14600k", "gpu": "rtx-5070"}},
    )

    assert response.status_code == 200
    assert response.json()["recommended_psu_watt"] == 750


def test_compat_rules_returns_stable_rule_catalog() -> None:
    client = make_client()

    response = client.get("/v1/compat/rules")

    assert response.status_code == 200
    body = response.json()
    codes = {rule["code"] for rule in body["rules"]}
    assert "cpu_motherboard_socket" in codes
    assert "motherboard_ram_type" in codes
    assert "psu_headroom" in codes
    assert "cpu_gpu_balance" in codes
    assert body["version"] == "2026-08-20"
