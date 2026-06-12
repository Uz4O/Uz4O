from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="APP_",
        extra="ignore",
    )

    service_name: str = "ai-pc-builder-api"
    postgres_url: Optional[str] = None
    redis_url: Optional[str] = None

    @property
    def sqlalchemy_database_url(self) -> Optional[str]:
        if self.postgres_url and self.postgres_url.startswith("postgresql://"):
            return self.postgres_url.replace("postgresql://", "postgresql+psycopg://", 1)
        return self.postgres_url
