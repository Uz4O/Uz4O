from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate
from app.builds.high_budget_catalog import generate_high_budget_templates
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
    reference_price: int = 1000,
    price_range_low: Optional[int] = None,
    price_range_high: Optional[int] = None,
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
                reference_price=reference_price,
                price_range_low=price_range_low if price_range_low is not None else reference_price - 100,
                price_range_high=price_range_high if price_range_high is not None else reference_price + 100,
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


def test_upsert_build_templates_persists_structured_high_budget_details() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    template = generate_high_budget_templates()[0]

    with Session(engine) as session:
        for part in template.details.parts:
            seed_component(
                session,
                part.component_id,
                part.role,
                specs=part.specs,
                reference_price=part.reference_price,
                price_range_low=part.reference_price,
                price_range_high=part.reference_price,
            )

        count = upsert_build_templates(session, [template])
        row = session.get(BuildTemplate, template.id)

    assert count == 1
    assert row.details["target_budget"] == 7_500
    assert row.details["direction"] == "fps"
    assert len(row.details["parts"]) == 8
    assert row.details["parts"][0]["reference_price"] > 0


def test_detailed_template_rejects_purchase_mode_condition_mismatch() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    template = generate_high_budget_templates()[0].model_copy(deep=True)
    template.details.purchase_mode = "used"

    with Session(engine) as session:
        try:
            upsert_build_templates(session, [template])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected detailed condition validation to fail")

    assert "conditions do not match purchase mode" in error


def test_detailed_template_rejects_reference_price_outside_condition_range() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    template = generate_high_budget_templates()[0].model_copy(deep=True)
    original_prices = {
        part.component_id: part.reference_price for part in template.details.parts
    }
    template.details.parts[0].reference_price = 1
    template.estimated_total = sum(
        part.reference_price for part in template.details.parts
    )

    with Session(engine) as session:
        for part in template.details.parts:
            expected_price = original_prices[part.component_id]
            seed_component(
                session,
                part.component_id,
                part.role,
                specs=part.specs,
                reference_price=expected_price,
                price_range_low=expected_price,
                price_range_high=expected_price,
            )
        try:
            upsert_build_templates(session, [template])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected detailed price validation to fail")

    assert "reference price does not match new price" in error


def test_detailed_template_rejects_role_category_mismatch() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    template = generate_high_budget_templates()[0]

    with Session(engine) as session:
        for part in template.details.parts:
            seed_component(
                session,
                part.component_id,
                "gpu" if part.role == "cpu" else part.role,
                specs=part.specs,
                reference_price=part.reference_price,
                price_range_low=part.reference_price,
                price_range_high=part.reference_price,
            )
        try:
            upsert_build_templates(session, [template])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected detailed role validation to fail")

    assert "category does not match cpu role" in error


def test_detailed_template_rejects_target_and_tag_mismatch() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    template = generate_high_budget_templates()[0].model_copy(deep=True)
    template.details.target_budget = 8_000
    template.tags.remove("FPS")

    with Session(engine) as session:
        try:
            upsert_build_templates(session, [template])
        except ValueError as exc:
            error = str(exc)
        else:
            raise AssertionError("Expected detailed metadata validation to fail")

    assert "target budget does not match budget_min" in error
    assert "tags do not match structured details" in error


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
