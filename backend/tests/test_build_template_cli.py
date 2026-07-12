from pathlib import Path

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildTemplateDetails
from app.builds.templates import read_build_template_inputs
from app.catalog.models import ComponentPrice, HardwareComponent
from app.cli import main
from app.db import Base


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"
SUPPORT_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"
CATALOG_PATHS = {
    "low": {
        "prices": DATA_DIR / "low-budget-base-reference-prices.csv",
        "recommendations": DATA_DIR / "low-budget-base-recommendation-ids.txt",
        "templates": DATA_DIR / "low-budget-base-build-templates.json",
    },
    "high": {
        "prices": DATA_DIR / "high-budget-base-reference-prices.csv",
        "recommendations": DATA_DIR / "high-budget-base-recommendation-ids.txt",
        "templates": DATA_DIR / "high-budget-base-build-templates.json",
    },
}


def test_import_build_templates_command_imports_json(monkeypatch, tmp_path: Path, capsys) -> None:
    captured = {}
    path = tmp_path / "build-templates.json"
    path.write_text(
        """
[
  {
    "id": "gaming-7000-2k",
    "title": "7000 元 2K 游戏配置",
    "budget_min": 6500,
    "budget_max": 7500,
    "use_cases": ["gaming"],
    "tags": ["2k", "quiet"],
    "components": {"cpu": "i5-14600k", "motherboard": "b760m", "ram": "ram-6000-cl30", "psu": "psu-750w"},
    "estimated_total": 7000,
    "explanation": "适合 2K 游戏。"
  }
]
""",
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_upsert_build_templates(session, templates):
        captured["templates"] = templates
        return len(templates)

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.upsert_build_templates", fake_upsert_build_templates)
    monkeypatch.setattr("sys.argv", ["ai-pc-builder-api", "import-build-templates", str(path)])

    main()

    assert captured["templates"][0].id == "gaming-7000-2k"
    assert capsys.readouterr().out == "Imported 1 build templates.\n"


@pytest.mark.parametrize("catalog_order", [("low", "high"), ("high", "low")])
def test_real_cli_catalog_imports_are_order_safe(
    catalog_order,
    monkeypatch,
    tmp_path: Path,
) -> None:
    database_path = tmp_path / f"{'-'.join(catalog_order)}.sqlite3"
    database_url = f"sqlite+pysqlite:///{database_path}"
    engine = create_engine(database_url)
    Base.metadata.create_all(engine)
    monkeypatch.setenv("APP_POSTGRES_URL", database_url)

    _run_cli(monkeypatch, "seed-hardware", SWIFT_CATALOG_PATH)
    _run_cli(monkeypatch, "seed-hardware", SUPPORT_PATH)
    for catalog_name in catalog_order:
        paths = CATALOG_PATHS[catalog_name]
        _run_cli(
            monkeypatch,
            "ingest-prices",
            paths["prices"],
            "--approved-at",
            "2026-07-12",
        )
        _run_cli(
            monkeypatch,
            "import-recommendations",
            paths["recommendations"],
        )
        _run_cli(
            monkeypatch,
            "import-build-templates",
            paths["templates"],
        )

    expected_templates = [
        *read_build_template_inputs(CATALOG_PATHS["low"]["templates"]),
        *read_build_template_inputs(CATALOG_PATHS["high"]["templates"]),
    ]
    with Session(engine) as session:
        stored_templates = list(session.scalars(select(BuildTemplate)))
        prices = {
            price.component_id: price
            for price in session.scalars(select(ComponentPrice))
        }
        components = {
            component.id: component
            for component in session.scalars(select(HardwareComponent))
        }
        assert len(stored_templates) == 297
        assert len({template.id for template in stored_templates}) == 297
        for template in stored_templates:
            details = BuildTemplateDetails.model_validate(template.details)
            assert len(details.parts) == 8
            for part in details.parts:
                price = prices[part.component_id]
                expected_price = (
                    price.price_range_high
                    if part.condition == "new"
                    else price.price_range_low
                )
                assert part.reference_price == expected_price
                assert components[part.component_id].is_recommended is True
        revalidated_count = upsert_build_templates(session, expected_templates)

    assert revalidated_count == 297


def _run_cli(monkeypatch, *args) -> None:
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", *(str(arg) for arg in args)],
    )
    main()
