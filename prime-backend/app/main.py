import logging
import re
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from .config import get_settings
from .db import create_db_schema
from .logging_config import configure_logging
from .middleware import request_log_middleware, security_headers_middleware
from .routers import auth, catalog, chat, groups, notifications, reports, social, users, waiting_room


settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger("prime.app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("starting_prime_api")
    await create_db_schema()
    yield
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
app.middleware("http")(request_log_middleware)
Path("uploads").mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
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
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Vary"] = "Origin"
    request_id = getattr(request.state, "request_id", None)
    if request_id:
        response.headers["X-Request-ID"] = request_id
    return response


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException,
) -> JSONResponse:
    detail = exc.detail
    if not isinstance(detail, str):
        detail = str(detail)
    response = JSONResponse(status_code=exc.status_code, content={"detail": detail})
    return _apply_cors_headers(request, response)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    response = JSONResponse(status_code=422, content={"detail": exc.errors()})
    return _apply_cors_headers(request, response)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled_exception", exc_info=exc)
    response = JSONResponse(
        status_code=500,
        content={"detail": "Внутренняя ошибка сервера"},
    )
    return _apply_cors_headers(request, response)


app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_origin_regex=_cors_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(catalog.router, prefix="/api/v1")
app.include_router(social.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
app.include_router(waiting_room.router, prefix="/api/v1")
app.include_router(groups.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
