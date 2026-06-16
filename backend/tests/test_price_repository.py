from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.prices import read_approved_price_rows
from app.catalog.repository import seed_component_prices
from app.db import Base


def test_seed_component_prices_upserts_approved_rows(tmp_path) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    path = tmp_path / "approved-reference-prices.csv"
    path.write_text(
        "\n".join(
            [
                "category,target_id,name,brand,reference_price,normal_price_min,normal_price_max,accepted_count,rejected_count,review_reasons",
                "gpu,rtx-5070,RTX 5070,NVIDIA,4799,4699,4899,3,1,manual_check",
            ]
        ),
        encoding="utf-8",
    )
    rows = read_approved_price_rows(path, approved_at="2026-06-15")

    with Session(engine) as session:
        session.add(
            HardwareComponent(
                id="rtx-5070",
                category="gpu",
                name="RTX 5070",
                brand="NVIDIA",
                detail_raw="NVIDIA",
                specs={},
            )
        )
        session.commit()

        assert seed_component_prices(session, rows) == 1
        assert seed_component_prices(session, rows) == 1
        prices = session.scalars(select(ComponentPrice)).all()

    assert len(prices) == 1
    assert prices[0].component_id == "rtx-5070"
    assert prices[0].reference_price == 4799
    assert prices[0].price_range_low == 4699
    assert prices[0].price_range_high == 4899
    assert prices[0].source == "approved-reference-prices.csv"
    assert prices[0].review_reasons == ["manual_check"]
