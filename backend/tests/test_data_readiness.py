from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.readiness import build_data_readiness
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base


def test_data_readiness_reports_missing_recommended_categories() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 · LGA1700",
                    specs={"socket": "LGA1700"},
                )
            ],
        )
        readiness = build_data_readiness(session)

    assert readiness.ready is False
    assert readiness.component_count == 1
    assert readiness.price_count == 0
    assert readiness.active_template_count == 0
    assert "gpu" in readiness.missing_recommended_categories


def test_data_readiness_requires_prices_for_each_recommended_category() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        CatalogComponent(id="cpu-1", category="cpu", name="CPU", brand="Intel", detail_raw="", specs={}),
        CatalogComponent(id="gpu-1", category="gpu", name="GPU", brand="NVIDIA", detail_raw="", specs={}),
        CatalogComponent(id="mb-1", category="motherboard", name="MB", brand="华硕", detail_raw="", specs={}),
        CatalogComponent(id="ram-1", category="ram", name="RAM", brand="金士顿", detail_raw="", specs={}),
        CatalogComponent(id="ssd-1", category="storage", name="SSD", brand="致态", detail_raw="", specs={}),
        CatalogComponent(id="psu-1", category="psu", name="PSU", brand="海韵", detail_raw="", specs={}),
    ]

    with Session(engine) as session:
        seed_hardware_components(session, components)
        for component in session.query(HardwareComponent):
            component.is_recommended = True
        session.add(
            ComponentPrice(
                component_id="cpu-1",
                reference_price=1200,
                price_range_low=1100,
                price_range_high=1300,
                source="manual",
                accepted_count=3,
                rejected_count=0,
                review_reasons=[],
                approved_at=datetime.now(timezone.utc),
            )
        )
        session.add(
            BuildTemplate(
                id="template-1",
                title="模板",
                budget_min=5000,
                budget_max=7000,
                use_cases=["gaming"],
                tags=[],
                components={"cpu": "cpu-1"},
                estimated_total=6000,
                explanation="人工审核模板。",
            )
        )
        session.commit()

        readiness = build_data_readiness(session)

    assert readiness.ready is False
    assert readiness.price_count == 1
    assert readiness.active_template_count == 1
    assert readiness.missing_recommended_categories == []
    assert readiness.priced_recommended_counts["cpu"] == 1
    assert readiness.priced_recommended_counts["gpu"] == 0
    assert readiness.missing_priced_recommended_categories == [
        "gpu",
        "motherboard",
        "ram",
        "storage",
        "psu",
    ]


def test_data_readiness_is_ready_when_every_recommended_category_has_prices_and_template() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        CatalogComponent(id="cpu-1", category="cpu", name="CPU", brand="Intel", detail_raw="", specs={}),
        CatalogComponent(id="gpu-1", category="gpu", name="GPU", brand="NVIDIA", detail_raw="", specs={}),
        CatalogComponent(id="mb-1", category="motherboard", name="MB", brand="华硕", detail_raw="", specs={}),
        CatalogComponent(id="ram-1", category="ram", name="RAM", brand="金士顿", detail_raw="", specs={}),
        CatalogComponent(id="ssd-1", category="storage", name="SSD", brand="致态", detail_raw="", specs={}),
        CatalogComponent(id="psu-1", category="psu", name="PSU", brand="海韵", detail_raw="", specs={}),
    ]

    with Session(engine) as session:
        seed_hardware_components(session, components)
        for component in session.query(HardwareComponent):
            component.is_recommended = True
            session.add(
                ComponentPrice(
                    component_id=component.id,
                    reference_price=1200,
                    price_range_low=1100,
                    price_range_high=1300,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                )
            )
        session.add(
            BuildTemplate(
                id="template-1",
                title="模板",
                budget_min=5000,
                budget_max=7000,
                use_cases=["gaming"],
                tags=[],
                components={"cpu": "cpu-1"},
                estimated_total=6000,
                explanation="人工审核模板。",
            )
        )
        session.commit()

        readiness = build_data_readiness(session)

    assert readiness.ready is True
    assert readiness.price_count == 6
    assert readiness.active_template_count == 1
    assert readiness.missing_recommended_categories == []
    assert readiness.missing_priced_recommended_categories == []
