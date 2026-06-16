from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import seed_hardware_components, update_recommended_components
from app.catalog.seed import CatalogComponent
from app.db import Base


def test_seed_hardware_components_upserts_rows() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    first = CatalogComponent(
        id="i5-14600k",
        category="cpu",
        name="i5-14600K",
        brand="Intel",
        detail_raw="14代 Raptor Lake Refresh · LGA1700",
        specs={"socket": "LGA1700"},
    )
    updated = first.model_copy(update={"brand": "Intel Core"})

    with Session(engine) as session:
        assert seed_hardware_components(session, [first]) == 1
        session.get(HardwareComponent, "i5-14600k").is_recommended = True
        session.commit()
        assert seed_hardware_components(session, [updated]) == 1

        rows = session.scalars(select(HardwareComponent)).all()

    assert len(rows) == 1
    assert rows[0].id == "i5-14600k"
    assert rows[0].brand == "Intel Core"
    assert rows[0].is_recommended is True
    assert rows[0].status == "active"
    assert rows[0].specs == {"socket": "LGA1700"}


def test_update_recommended_components_can_replace_existing_recommendations() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        CatalogComponent(
            id="i5-14600k",
            category="cpu",
            name="i5-14600K",
            brand="Intel",
            detail_raw="14代 · LGA1700",
            specs={"socket": "LGA1700"},
        ),
        CatalogComponent(
            id="rtx-4060",
            category="gpu",
            name="RTX 4060",
            brand="NVIDIA",
            detail_raw="8GB",
            specs={},
        ),
        CatalogComponent(
            id="h610m",
            category="motherboard",
            name="H610M",
            brand="华硕",
            detail_raw="Intel · LGA1700 · H610",
            specs={"socket": "LGA1700"},
        ),
    ]

    with Session(engine) as session:
        seed_hardware_components(session, components)
        session.get(HardwareComponent, "h610m").is_recommended = True
        session.commit()

        result = update_recommended_components(
            session,
            ["i5-14600k", "rtx-4060"],
            replace=True,
        )

        assert result.updated_count == 2
        assert result.missing_ids == []
        assert session.get(HardwareComponent, "i5-14600k").is_recommended is True
        assert session.get(HardwareComponent, "rtx-4060").is_recommended is True
        assert session.get(HardwareComponent, "h610m").is_recommended is False


def test_update_recommended_components_reports_missing_ids() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        result = update_recommended_components(session, ["missing-cpu"], replace=True)

    assert result.updated_count == 0
    assert result.missing_ids == ["missing-cpu"]
