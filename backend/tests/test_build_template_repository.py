from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildTemplateInput
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.db import Base


def template_input(**overrides) -> BuildTemplateInput:
    values = {
        "id": "gaming-7000-2k",
        "title": "7000 元 2K 游戏配置",
        "budget_min": 6500,
        "budget_max": 7500,
        "use_cases": ["gaming"],
        "tags": ["2k"],
        "components": {
            "cpu": "i5-14600k",
            "gpu": "rtx-4060",
            "motherboard": "b760m",
            "ram": "ram-6000",
            "psu": "psu-750w",
        },
        "estimated_total": 7000,
        "explanation": "人工审核模板。",
    }
    values.update(overrides)
    return BuildTemplateInput(**values)


def seed_component(
    session: Session,
    component_id: str,
    category: str,
    *,
    recommended: bool = True,
    priced: bool = True,
    specs: Optional[dict] = None,
) -> None:
    seed_hardware_components(
        session,
        [
            CatalogComponent(
                id=component_id,
                category=category,
                name=component_id,
                brand="brand",
                detail_raw="",
                specs=specs or {},
            )
        ],
    )
    component = session.get(HardwareComponent, component_id)
    component.is_recommended = recommended
    if priced:
        session.add(
            ComponentPrice(
                component_id=component_id,
                reference_price=1000,
                price_range_low=900,
                price_range_high=1100,
                source="manual",
                accepted_count=3,
                rejected_count=0,
                review_reasons=[],
                approved_at=datetime.now(timezone.utc),
            )
        )
    session.commit()


def test_upsert_build_templates_rejects_unknown_component_ids() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        try:
            upsert_build_templates(session, [template_input()])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected template validation to fail")

    assert "unknown component ids" in error
    assert "i5-14600k" in error
    assert "rtx-4060" in error


def test_upsert_build_templates_rejects_invalid_template_shape() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        try:
            upsert_build_templates(
                session,
                [
                    template_input(
                        budget_min=7500,
                        budget_max=6500,
                        estimated_total=8000,
                        components={"cpu": "i5-14600k"},
                    )
                ],
            )
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected template shape validation to fail")

    assert "budget_min greater than budget_max" in error
    assert "estimated_total outside budget range" in error
    assert "missing required roles" in error
    assert "motherboard" in error
    assert "ram" in error
    assert "psu" in error


def test_upsert_build_templates_rejects_unrecommended_or_unpriced_components() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        seed_component(session, "i5-14600k", "cpu", recommended=False, priced=True)
        seed_component(session, "rtx-4060", "gpu", recommended=True, priced=False)

        try:
            upsert_build_templates(session, [template_input()])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected template validation to fail")

    assert "not recommended component ids" in error
    assert "i5-14600k" in error
    assert "missing price component ids" in error
    assert "rtx-4060" in error


def test_upsert_build_templates_accepts_recommended_priced_components() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        seed_component(session, "i5-14600k", "cpu", specs={"socket": "LGA1700"})
        seed_component(session, "rtx-4060", "gpu")
        seed_component(session, "b760m", "motherboard", specs={"socket": "LGA1700", "mem_type": "DDR5"})
        seed_component(session, "ram-6000", "ram", specs={"type": "DDR5"})
        seed_component(session, "psu-750w", "psu", specs={"watt": 750})

        count = upsert_build_templates(session, [template_input()])

        rows = list(session.scalars(select(BuildTemplate)))

    assert count == 1
    assert rows[0].id == "gaming-7000-2k"


def test_upsert_build_templates_rejects_incompatible_templates() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        seed_component(session, "i5-14600k", "cpu", specs={"socket": "LGA1700"})
        seed_component(session, "am5-board", "motherboard", specs={"socket": "AM5"})
        seed_component(session, "rtx-4060", "gpu")
        seed_component(session, "ram-6000", "ram")
        seed_component(session, "psu-750w", "psu")

        try:
            upsert_build_templates(
                session,
                [
                    template_input(
                        components={
                            "cpu": "i5-14600k",
                            "motherboard": "am5-board",
                            "gpu": "rtx-4060",
                            "ram": "ram-6000",
                            "psu": "psu-750w",
                        }
                    )
                ],
            )
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected incompatible template validation to fail")

    assert "incompatible build template" in error
    assert "gaming-7000-2k" in error
    assert "cpu_motherboard_socket" in error
