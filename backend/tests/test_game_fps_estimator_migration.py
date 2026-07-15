from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect


BACKEND_ROOT = Path(__file__).resolve().parents[1]
NEW_TABLES = {
    "hardware_performance_profile",
    "game_performance_anchor",
    "game_performance_calibration",
}


def test_game_fps_estimator_migration_round_trip(tmp_path, monkeypatch) -> None:
    database_path = tmp_path / "fps-estimator.sqlite3"
    database_url = f"sqlite+pysqlite:///{database_path}"
    monkeypatch.chdir(BACKEND_ROOT)
    monkeypatch.setenv("APP_POSTGRES_URL", database_url)
    config = Config(str(BACKEND_ROOT / "alembic.ini"))

    command.upgrade(config, "20260713_0012")
    engine = create_engine(database_url)
    assert NEW_TABLES.isdisjoint(inspect(engine).get_table_names())

    command.upgrade(config, "head")
    inspector = inspect(engine)
    assert NEW_TABLES.issubset(inspector.get_table_names())
    assert "ix_game_perf_anchor_lookup" in {
        item["name"]
        for item in inspector.get_indexes("game_performance_anchor")
    }
    assert "ix_game_perf_calibration_active" in {
        item["name"]
        for item in inspector.get_indexes("game_performance_calibration")
    }
    for table_name, constraint_name in (
        ("hardware_performance_profile", "ck_hardware_perf_source_kind"),
        ("game_performance_anchor", "ck_game_perf_anchor_source_kind"),
    ):
        constraints = {
            item["name"]: item["sqltext"]
            for item in inspector.get_check_constraints(table_name)
        }
        assert "public_reference" in constraints[constraint_name]

    command.downgrade(config, "20260713_0012")
    assert NEW_TABLES.isdisjoint(inspect(engine).get_table_names())

    command.upgrade(config, "head")
    assert NEW_TABLES.issubset(inspect(engine).get_table_names())
