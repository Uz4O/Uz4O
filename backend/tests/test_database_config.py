from app.core.config import Settings
from app import db


def test_sqlalchemy_database_url_uses_psycopg_driver() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://user:pass@127.0.0.1:5432/app",
    )

    assert settings.sqlalchemy_database_url == "postgresql+psycopg://user:pass@127.0.0.1:5432/app"


def test_session_factory_is_reused_for_same_database_url(monkeypatch) -> None:
    calls = []

    def fake_create_engine(database_url: str):
        calls.append(database_url)
        return object()

    monkeypatch.setattr(db, "create_engine", fake_create_engine)
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://user:pass@127.0.0.1:5432/app",
    )

    first = db.create_session_factory(settings)
    second = db.create_session_factory(settings)

    assert first is second
    assert calls == ["postgresql+psycopg://user:pass@127.0.0.1:5432/app"]
