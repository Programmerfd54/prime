from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(alias="DATABASE_URL")
    jwt_secret_key: str = Field(alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(
        default=43200,
        alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    cors_allowed_origins: str = Field(
        default=(
            "http://localhost:3000,http://localhost:5000,"
            "http://localhost:8080,http://localhost:8081,"
            "http://127.0.0.1:8080,http://127.0.0.1:8081"
        ),
        alias="CORS_ALLOWED_ORIGINS",
    )
    # Flutter web uses a random localhost port; regex covers any local origin.
    # Leave empty in production.
    cors_allow_origin_regex: str = Field(
        default=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
        alias="CORS_ALLOW_ORIGIN_REGEX",
    )
    api_docs_enabled: bool = Field(default=False, alias="API_DOCS_ENABLED")
    auth_login_rate_limit_enabled: bool = Field(
        default=True,
        alias="AUTH_LOGIN_RATE_LIMIT_ENABLED",
    )
    auth_login_rate_limit_attempts: int = Field(
        default=8,
        ge=1,
        alias="AUTH_LOGIN_RATE_LIMIT_ATTEMPTS",
    )
    auth_login_rate_limit_window_seconds: int = Field(
        default=300,
        ge=1,
        alias="AUTH_LOGIN_RATE_LIMIT_WINDOW_SECONDS",
    )
    enable_dev_tools: bool = Field(default=False, alias="ENABLE_DEV_TOOLS")
    dev_passwordless_emails: str = Field(
        default="",
        alias="DEV_PASSWORDLESS_EMAILS",
    )
    # When true (local/dev), forgot-password response includes reset_token.
    # Production should keep false and deliver tokens via email/ops.
    password_reset_expose_token: bool = Field(
        default=False,
        alias="PASSWORD_RESET_EXPOSE_TOKEN",
    )
    password_reset_token_ttl_minutes: int = Field(
        default=60,
        ge=5,
        alias="PASSWORD_RESET_TOKEN_TTL_MINUTES",
    )
    group_region_expansion_minutes: int = Field(
        default=15,
        ge=1,
        alias="GROUP_REGION_EXPANSION_MINUTES",
    )
    group_partial_start_hours: int = Field(
        default=12,
        ge=1,
        alias="GROUP_PARTIAL_START_HOURS",
    )
    group_min_members: int = Field(
        default=3,
        ge=3,
        alias="GROUP_MIN_MEMBERS",
    )
    matrix_enabled: bool = Field(default=False, alias="MATRIX_ENABLED")
    matrix_base_url: str = Field(default="http://matrix-synapse:8008", alias="MATRIX_BASE_URL")
    matrix_public_base_url: str = Field(default="", alias="MATRIX_PUBLIC_BASE_URL")
    matrix_server_name: str = Field(default="localhost", alias="MATRIX_SERVER_NAME")
    matrix_shared_secret: str = Field(default="", alias="MATRIX_SHARED_SECRET")

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
