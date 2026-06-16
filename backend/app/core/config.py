import ipaddress
from typing import Optional
from urllib.parse import urlparse

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="APP_",
        extra="ignore",
    )

    service_name: str = "ai-pc-builder-api"
    app_env: str = Field(default="development", validation_alias=AliasChoices("APP_ENV", "app_env"))
    postgres_url: Optional[str] = None
    redis_url: Optional[str] = None
    auth_token_secret: str = "dev-only-change-me"
    auth_sms_debug: bool = True
    ai_provider_api_key: Optional[str] = None
    ai_provider_base_url: str = "https://api.deepseek.com"
    ai_model: str = "deepseek-v4-flash"
    ai_provider_timeout_seconds: float = 8.0
    high_cost_rate_limit_enabled: bool = True
    high_cost_rate_limit_max_requests: int = 30
    high_cost_rate_limit_window_seconds: int = 60
    high_cost_estimated_cost_cents: int = 0
    auth_rate_limit_enabled: bool = True
    auth_sms_rate_limit_max_requests: int = 5
    auth_login_rate_limit_max_requests: int = 10
    auth_rate_limit_window_seconds: int = 60
    response_cache_enabled: bool = True
    response_cache_ttl_seconds: int = 300
    response_cache_max_entries: int = 512
    max_request_body_bytes: int = 1_000_000
    ops_token: Optional[str] = None
    community_image_upload_enabled: bool = False
    community_image_max_bytes: int = 5_000_000
    community_image_oss_bucket: Optional[str] = None
    community_image_oss_region: Optional[str] = None
    community_image_oss_access_key_id: Optional[str] = None
    community_image_oss_access_key_secret: Optional[str] = None
    community_image_oss_security_token: Optional[str] = None
    community_write_rate_limit_enabled: bool = True
    community_write_rate_limit_max_requests: int = 60
    community_write_rate_limit_window_seconds: int = 60
    apple_login_client_id: Optional[str] = None
    cors_allowed_origins: str = ""
    api_docs_enabled: bool = False
    production_data_readiness_required: bool = False

    @property
    def sqlalchemy_database_url(self) -> Optional[str]:
        if self.postgres_url and self.postgres_url.startswith("postgresql://"):
            return self.postgres_url.replace("postgresql://", "postgresql+psycopg://", 1)
        return self.postgres_url

    @property
    def ai_provider_chat_url(self) -> str:
        return self.ai_provider_base_url.rstrip("/") + "/chat/completions"

    @property
    def ai_provider_base_url_status(self) -> str:
        return _external_https_url_status(self.ai_provider_base_url)

    @property
    def cors_origin_list(self) -> list[str]:
        origins = self.raw_cors_origin_list
        if any(_cors_origin_status(origin) != "configured" for origin in origins):
            return []
        return origins

    @property
    def raw_cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]

    @property
    def cors_allowed_origins_status(self) -> str:
        origins = self.raw_cors_origin_list
        if not origins:
            return "not_configured"
        if any(_cors_origin_status(origin) != "configured" for origin in origins):
            return "invalid"
        return "configured"

    @property
    def community_image_upload_configured(self) -> bool:
        return all(
            [
                self.community_image_upload_enabled,
                self.community_image_oss_bucket,
                self.community_image_oss_region,
                self.community_image_oss_access_key_id,
                self.community_image_oss_access_key_secret,
            ]
        )

    @property
    def community_image_oss_host(self) -> Optional[str]:
        if not self.community_image_oss_bucket or not self.community_image_oss_region:
            return None
        return (
            f"https://{self.community_image_oss_bucket}"
            f".oss-{self.community_image_oss_region}.aliyuncs.com"
        )


def _cors_origin_status(origin: str) -> str:
    if origin == "*":
        return "invalid"
    parsed = urlparse(origin)
    if parsed.scheme not in {"http", "https"}:
        return "invalid"
    if not parsed.netloc:
        return "invalid"
    if parsed.path not in {"", "/"} or parsed.params or parsed.query or parsed.fragment:
        return "invalid"
    return "configured"


def _external_https_url_status(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "https":
        return "invalid"
    if not parsed.hostname:
        return "invalid"
    hostname = parsed.hostname.lower()
    if hostname in {"localhost", "localhost.localdomain"}:
        return "invalid"
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        return "configured"
    if (
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_reserved
        or address.is_multicast
        or address.is_unspecified
    ):
        return "invalid"
    return "configured"
