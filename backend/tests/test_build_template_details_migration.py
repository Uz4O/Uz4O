from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import MetaData, Table, create_engine, inspect, select


BACKEND_ROOT = Path(__file__).resolve().parents[1]


def test_migrates_existing_build_templates_to_structured_details(
    tmp_path,
    monkeypatch,
) -> None:
    database_path = tmp_path / "migration.sqlite3"
    database_url = f"sqlite+pysqlite:///{database_path}"
    monkeypatch.chdir(BACKEND_ROOT)
    monkeypatch.setenv("APP_POSTGRES_URL", database_url)
    config = Config(str(BACKEND_ROOT / "alembic.ini"))

    command.upgrade(config, "20260707_0010")
    engine = create_engine(database_url)
    metadata = MetaData()
    build_template = Table("build_template", metadata, autoload_with=engine)
    with engine.begin() as connection:
        connection.execute(
            build_template.insert().values(
                id="legacy-template",
                title="Legacy",
                budget_min=7_000,
                budget_max=7_500,
                use_cases=["游戏"],
                tags=[],
                components={},
                estimated_total=7_200,
                explanation="legacy row",
                status="active",
            )
        )

    command.upgrade(config, "head")

    migrated_metadata = MetaData()
    migrated_table = Table("build_template", migrated_metadata, autoload_with=engine)
    with engine.connect() as connection:
        details = connection.scalar(
            select(migrated_table.c.details).where(
                migrated_table.c.id == "legacy-template"
            )
        )
    columns = {column["name"]: column for column in inspect(engine).get_columns("build_template")}

    assert details == {}
    assert columns["details"]["nullable"] is False
