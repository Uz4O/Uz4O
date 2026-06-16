from functools import lru_cache
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import Settings


class Base(DeclarativeBase):
    pass


def create_database_engine(settings: Settings):
    if not settings.sqlalchemy_database_url:
        raise RuntimeError("APP_POSTGRES_URL is required for database operations")
    return create_engine(settings.sqlalchemy_database_url)


def create_session_factory(settings: Settings):
    if not settings.sqlalchemy_database_url:
        raise RuntimeError("APP_POSTGRES_URL is required for database operations")
    return _create_session_factory(settings.sqlalchemy_database_url)


@lru_cache(maxsize=8)
def _create_session_factory(database_url: str):
    return sessionmaker(bind=create_engine(database_url), expire_on_commit=False)


def get_session() -> Generator[Session, None, None]:
    session_factory = create_session_factory(Settings())
    with session_factory() as session:
        yield session
