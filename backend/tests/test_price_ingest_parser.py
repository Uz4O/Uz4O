from pathlib import Path

from app.catalog.prices import read_approved_price_rows


def test_reads_approved_price_rows(tmp_path: Path) -> None:
    path = tmp_path / "approved-reference-prices.csv"
    path.write_text(
        "\n".join(
            [
                "category,target_id,name,brand,reference_price,normal_price_min,normal_price_max,accepted_count,rejected_count,review_reasons",
                "gpu,rtx-5070,RTX 5070,NVIDIA,4799,4699,4899,3,1,",
                "cpu,i5-14600k,i5-14600K,Intel,1499,1450,1550,4,0,price_outliers_removed|manual_check",
            ]
        ),
        encoding="utf-8",
    )

    rows = read_approved_price_rows(path, approved_at="2026-06-15")

    assert [row.component_id for row in rows] == ["rtx-5070", "i5-14600k"]
    assert rows[0].reference_price == 4799
    assert rows[0].price_range_low == 4699
    assert rows[0].price_range_high == 4899
    assert rows[0].accepted_count == 3
    assert rows[1].review_reasons == ["price_outliers_removed", "manual_check"]
    assert rows[1].approved_at.isoformat() == "2026-06-15T00:00:00+08:00"


def test_skips_rows_without_reference_price(tmp_path: Path) -> None:
    path = tmp_path / "approved-reference-prices.csv"
    path.write_text(
        "\n".join(
            [
                "category,target_id,name,brand,reference_price,normal_price_min,normal_price_max,accepted_count,rejected_count,review_reasons",
                "gpu,rtx-5070,RTX 5070,NVIDIA,,,,0,3,no_accepted_products",
            ]
        ),
        encoding="utf-8",
    )

    assert read_approved_price_rows(path, approved_at="2026-06-15") == []
