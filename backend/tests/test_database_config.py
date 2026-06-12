from app.core.config import Settings


def test_sqlalchemy_database_url_uses_psycopg_driver() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://user:pass@127.0.0.1:5432/app",
    )

    assert settings.sqlalchemy_database_url == "postgresql+psycopg://user:pass@127.0.0.1:5432/app"
