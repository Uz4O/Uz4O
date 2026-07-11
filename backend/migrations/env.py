from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.auth.models import Account, AuthSmsCode
from app.builds.models import BuildTemplate
from app.catalog.models import ComponentPrice, CPUWhitelistPrice, GPUWhitelistPrice, HardwareComponent, MotherboardWhitelistPrice
from app.profile.models import HardwareProfile, OnboardingProfile
from app.core.config import Settings
from app.db import Base


config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

settings = Settings()
if settings.sqlalchemy_database_url:
    config.set_main_option("sqlalchemy.url", settings.sqlalchemy_database_url)
else:
    config.set_main_option("sqlalchemy.url", "postgresql://")

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
