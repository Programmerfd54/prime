import logging
import re
import asyncio
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from .config import get_settings
from .db import SessionLocal, create_db_schema
from .logging_config import configure_logging
from .middleware import request_log_middleware, security_headers_middleware
from .rate_limit_middleware import global_rate_limit_middleware
from .matrix import migrate_legacy_tokens
from .email_unsubscribe_cleanup import run_email_unsubscribe_cleanup_worker
from .outbox_worker import run_outbox_worker
from .media_pipeline.worker import run_media_worker
from .redis_client import close_redis
from .direct_message_events import close_direct_message_hub
from .routers import auth, catalog, chat, email, groups, moderation, mfa, notifications, ops, reports, social, users, waiting_room


settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger("prime.app")


def _validate_production_settings() -> None:
    if not settings.is_production:
        return
    if settings.enable_dev_tools:
        raise RuntimeError("ENABLE_DEV_TOOLS must be false in production")
    if settings.email_verification_expose_code:
        raise RuntimeError("EMAIL_VERIFICATION_EXPOSE_CODE must be false in production")
    if settings.cors_allow_origin_regex.strip():
        raise RuntimeError("CORS_ALLOW_ORIGIN_REGEX must be empty in production")
    if not settings.cors_allowed_origins.strip():
        raise RuntimeError("CORS_ALLOWED_ORIGINS must be set in production")
    if not settings.moderator_features_enabled:
        return
    if not settings.moderator_mfa_enforce:
        raise RuntimeError("MODERATOR_MFA_ENFORCE must be true in production when moderator features are enabled")


@asynccontextmanager
async def lifespan(app: FastAPI):
    _validate_production_settings()
    logger.info("starting_prime_api")
    if settings.run_db_migrations:
        await create_db_schema()
    async with SessionLocal() as session:
        migrated = await migrate_legacy_tokens(session)
        if migrated:
            logger.info("matrix_tokens_encrypted", extra={"count": migrated})
    stop_event = asyncio.Event()
    workers = []
    if settings.run_background_workers:
        workers = [
            asyncio.create_task(run_outbox_worker(stop_event)),
            asyncio.create_task(run_media_worker(stop_event)),
            asyncio.create_task(run_email_unsubscribe_cleanup_worker(stop_event)),
        ]
    try:
        yield
    finally:
        stop_event.set()
        for worker in workers:
            worker.cancel()
        if workers:
            await asyncio.gather(*workers, return_exceptions=True)
        await close_direct_message_hub()
        await close_redis()
    logger.info("stopping_prime_api")


docs_url = "/docs" if settings.api_docs_enabled else None
redoc_url = "/redoc" if settings.api_docs_enabled else None
openapi_url = "/openapi.json" if settings.api_docs_enabled else None

app = FastAPI(
    title="PRIME API",
    version="0.1.0",
    lifespan=lifespan,
    docs_url=docs_url,
    redoc_url=redoc_url,
    openapi_url=openapi_url,
)
app.middleware("http")(security_headers_middleware)
app.middleware("http")(global_rate_limit_middleware)
app.middleware("http")(request_log_middleware)
Path("uploads").mkdir(parents=True, exist_ok=True)
_cors_origins = [
    origin.strip()
    for origin in settings.cors_allowed_origins.split(",")
    if origin.strip()
]
_cors_regex = settings.cors_allow_origin_regex.strip() or None


def _cors_allow_origin(origin: str | None) -> str | None:
    if not origin:
        return None
    if origin in _cors_origins:
        return origin
    if _cors_regex and re.fullmatch(_cors_regex, origin):
        return origin
    return None


def _apply_cors_headers(request: Request, response: JSONResponse) -> JSONResponse:
    origin = _cors_allow_origin(request.headers.get("origin"))
    if origin:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Vary"] = "Origin"
    request_id = getattr(request.state, "request_id", None)
    if request_id:
        response.headers["X-Request-ID"] = request_id
    return response


def _error_payload(
    request: Request,
    *,
    status_code: int,
    message: str,
    fields: list[dict] | None = None,
    retryable: bool | None = None,
) -> dict:
    request_id = getattr(request.state, "request_id", None)
    return {
        "detail": message,
        "error": {
            "code": f"HTTP_{status_code}",
            "message": message,
            "requestId": request_id,
            "retryable": retryable if retryable is not None else status_code >= 500 or status_code == 429,
            "fields": fields or [],
        },
    }


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException,
) -> JSONResponse:
    detail = exc.detail
    if not isinstance(detail, str):
        detail = str(detail)
    response = JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(request, status_code=exc.status_code, message=detail),
    )
    return _apply_cors_headers(request, response)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    fields = [
        {
            "field": ".".join(str(part) for part in error.get("loc", [])),
            "message": error.get("msg", "Некорректное значение"),
            "type": error.get("type", "validation_error"),
        }
        for error in exc.errors()
    ]
    response = JSONResponse(
        status_code=422,
        content=_error_payload(
            request,
            status_code=422,
            message="Ошибка валидации",
            fields=fields,
            retryable=False,
        ),
    )
    return _apply_cors_headers(request, response)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled_exception", exc_info=exc)
    response = JSONResponse(
        status_code=500,
        content=_error_payload(
            request,
            status_code=500,
            message="Внутренняя ошибка сервера",
            retryable=True,
        ),
    )
    return _apply_cors_headers(request, response)


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_origin_regex=_cors_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID", "Accept", "Cache-Control"],
    expose_headers=["X-Request-ID"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(email.router)
app.include_router(mfa.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(users.legacy_router, prefix="/api/v1")
app.include_router(catalog.router, prefix="/api/v1")
app.include_router(social.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
app.include_router(ops.router, prefix="/api/v1")
app.include_router(waiting_room.router, prefix="/api/v1")
app.include_router(groups.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(moderation.router, prefix="/api/v1")
app.include_router(moderation.ops_router, prefix="/api/v1")
