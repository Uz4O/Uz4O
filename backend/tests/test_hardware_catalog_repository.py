from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import seed_hardware_components
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
        assert seed_hardware_components(session, [updated]) == 1

        rows = session.scalars(select(HardwareComponent)).all()

    assert len(rows) == 1
    assert rows[0].id == "i5-14600k"
    assert rows[0].brand == "Intel Core"
    assert rows[0].is_recommended is False
    assert rows[0].status == "active"
    assert rows[0].specs == {"socket": "LGA1700"}
