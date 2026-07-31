from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(alias="DATABASE_URL")
    db_pool_size: int = Field(default=10, ge=1, alias="DB_POOL_SIZE")
    db_max_overflow: int = Field(default=10, ge=0, alias="DB_MAX_OVERFLOW")
    db_pool_timeout_seconds: int = Field(default=30, ge=1, alias="DB_POOL_TIMEOUT_SECONDS")
    db_pool_recycle_seconds: int = Field(default=1800, ge=60, alias="DB_POOL_RECYCLE_SECONDS")
    jwt_secret_key: str = Field(alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    jwt_issuer: str = Field(default="prime-api", alias="JWT_ISSUER")
    jwt_audience: str = Field(default="prime-client", alias="JWT_AUDIENCE")
    access_token_expire_minutes: int = Field(
        default=15,
        ge=1,
        alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    refresh_token_expire_days: int = Field(
        default=30,
        ge=1,
        le=90,
        alias="REFRESH_TOKEN_EXPIRE_DAYS",
    )
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    last_seen_write_interval_seconds: int = Field(
        default=60,
        ge=0,
        alias="LAST_SEEN_WRITE_INTERVAL_SECONDS",
    )
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
    # Kept for backwards-compatible environment parsing. Reset tokens are
    # never returned in HTTP responses; delivery is email-only.
    password_reset_expose_token: bool = Field(
        default=False,
        alias="PASSWORD_RESET_EXPOSE_TOKEN",
    )
    password_reset_token_ttl_minutes: int = Field(
        default=60,
        ge=5,
        alias="PASSWORD_RESET_TOKEN_TTL_MINUTES",
    )
    email_verification_code_ttl_minutes: int = Field(
        default=15,
        ge=1,
        alias="EMAIL_VERIFICATION_CODE_TTL_MINUTES",
    )
    # Wrong-code guesses allowed per issued code before a new one is required.
    email_verification_max_attempts: int = Field(
        default=5,
        ge=1,
        alias="EMAIL_VERIFICATION_MAX_ATTEMPTS",
    )
    email_verification_resend_cooldown_seconds: int = Field(
        default=60,
        ge=0,
        alias="EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS",
    )
    # When true (local/dev), register and resend responses include the code so
    # seeding tools and manual QA work without a mail server. Never in production.
    email_verification_expose_code: bool = Field(
        default=False,
        alias="EMAIL_VERIFICATION_EXPOSE_CODE",
    )
    smtp_host: str = Field(default="", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, ge=1, le=65535, alias="SMTP_PORT")
    smtp_username: str = Field(default="", alias="SMTP_USERNAME")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    # STARTTLS on 587/25, implicit TLS on 465. Set exactly one.
    smtp_use_starttls: bool = Field(default=True, alias="SMTP_USE_STARTTLS")
    smtp_use_ssl: bool = Field(default=False, alias="SMTP_USE_SSL")
    smtp_timeout_seconds: int = Field(default=15, ge=1, alias="SMTP_TIMEOUT_SECONDS")
    mail_from: str = Field(default="", alias="MAIL_FROM")
    mail_from_name: str = Field(default="ПРАЙМ", alias="MAIL_FROM_NAME")
    # Shown as Reply-To; use support@your-domain so users can answer if needed.
    mail_reply_to: str = Field(default="", alias="MAIL_REPLY_TO")
    # Public base URL for links embedded in outgoing mail (unsubscribe, etc.).
    public_api_base_url: str = Field(
        default="http://localhost:8080/api/v1",
        alias="PUBLIC_API_BASE_URL",
    )
    group_region_expansion_minutes: int = Field(
        default=5,
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
    match_candidate_scan_limit: int = Field(
        default=120,
        ge=6,
        alias="MATCH_CANDIDATE_SCAN_LIMIT",
    )
    matrix_enabled: bool = Field(default=False, alias="MATRIX_ENABLED")
    matrix_base_url: str = Field(default="http://matrix-synapse:8008", alias="MATRIX_BASE_URL")
    matrix_public_base_url: str = Field(default="", alias="MATRIX_PUBLIC_BASE_URL")
    matrix_server_name: str = Field(default="localhost", alias="MATRIX_SERVER_NAME")
    matrix_shared_secret: str = Field(default="", alias="MATRIX_SHARED_SECRET")
    matrix_token_encryption_key: str = Field(
        default="",
        alias="MATRIX_TOKEN_ENCRYPTION_KEY",
    )
    matrix_password_secret: str = Field(default="", alias="MATRIX_PASSWORD_SECRET")
    password_reset_rate_limit_attempts: int = Field(
        default=3,
        ge=1,
        alias="PASSWORD_RESET_RATE_LIMIT_ATTEMPTS",
    )
    password_reset_rate_limit_window_seconds: int = Field(
        default=900,
        ge=1,
        alias="PASSWORD_RESET_RATE_LIMIT_WINDOW_SECONDS",
    )
    upload_rate_limit_attempts: int = Field(
        default=30,
        ge=1,
        alias="UPLOAD_RATE_LIMIT_ATTEMPTS",
    )
    upload_rate_limit_window_seconds: int = Field(
        default=300,
        ge=1,
        alias="UPLOAD_RATE_LIMIT_WINDOW_SECONDS",
    )
    fcm_project_id: str = Field(default="", alias="FCM_PROJECT_ID")
    fcm_service_account_json: str = Field(
        default="",
        alias="FCM_SERVICE_ACCOUNT_JSON",
    )
    fcm_service_account_file: str = Field(
        default="",
        alias="FCM_SERVICE_ACCOUNT_FILE",
    )
    apns_key_id: str = Field(default="", alias="APNS_KEY_ID")
    apns_team_id: str = Field(default="", alias="APNS_TEAM_ID")
    apns_bundle_id: str = Field(default="", alias="APNS_BUNDLE_ID")
    apns_private_key: str = Field(default="", alias="APNS_PRIVATE_KEY")
    apns_use_sandbox: bool = Field(default=False, alias="APNS_USE_SANDBOX")
    push_timeout_seconds: int = Field(default=10, ge=1, le=60, alias="PUSH_TIMEOUT_SECONDS")
    app_env: str = Field(default="development", alias="APP_ENV")
    api_rate_limit_enabled: bool = Field(default=True, alias="API_RATE_LIMIT_ENABLED")
    api_rate_limit_requests: int = Field(default=300, ge=1, alias="API_RATE_LIMIT_REQUESTS")
    api_rate_limit_window_seconds: int = Field(
        default=60,
        ge=1,
        alias="API_RATE_LIMIT_WINDOW_SECONDS",
    )
    friend_request_rate_limit_attempts: int = Field(
        default=20,
        ge=1,
        alias="FRIEND_REQUEST_RATE_LIMIT_ATTEMPTS",
    )
    friend_request_rate_limit_window_seconds: int = Field(
        default=3600,
        ge=1,
        alias="FRIEND_REQUEST_RATE_LIMIT_WINDOW_SECONDS",
    )
    moderator_step_up_ttl_minutes: int = Field(
        default=15,
        ge=1,
        le=60,
        alias="MODERATOR_STEP_UP_TTL_MINUTES",
    )
    moderator_mfa_enforce: bool = Field(default=False, alias="MODERATOR_MFA_ENFORCE")
    moderator_features_enabled: bool = Field(
        default=False,
        alias="MODERATOR_FEATURES_ENABLED",
    )
    webauthn_rp_id: str = Field(default="localhost", alias="WEBAUTHN_RP_ID")
    webauthn_rp_name: str = Field(default="PRIME", alias="WEBAUTHN_RP_NAME")
    webauthn_origin: str = Field(default="http://localhost:8080", alias="WEBAUTHN_ORIGIN")
    media_scanner: str = Field(default="noop", alias="MEDIA_SCANNER")
    clamav_host: str = Field(default="127.0.0.1", alias="CLAMAV_HOST")
    clamav_port: int = Field(default=3310, ge=1, alias="CLAMAV_PORT")

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def is_production(self) -> bool:
        return self.app_env.strip().lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
