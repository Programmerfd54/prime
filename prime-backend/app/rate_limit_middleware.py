"""Global authenticated API rate limiting."""

from __future__ import annotations

from collections.abc import Awaitable, Callable

from fastapi import HTTPException, Request, Response
from starlette.responses import JSONResponse

from .audit import record_audit
from .config import get_settings
from .db import SessionLocal
from .rate_limit import enforce as enforce_rate_limit
from .rate_limit import record_failure as record_rate_limit_hit
from .security import decode_access_token_claims


_SKIP_PREFIXES = (
    "/api/v1/health",
    "/api/v1/auth/",
    "/docs",
    "/redoc",
    "/openapi.json",
)


def _should_skip(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in _SKIP_PREFIXES)


def _rate_key(request: Request) -> str | None:
    auth = request.headers.get("authorization") or ""
    if auth.lower().startswith("bearer "):
        token = auth[7:].strip()
        try:
            claims = decode_access_token_claims(token)
            user_id = claims.get("sub")
            if isinstance(user_id, str) and user_id:
                return f"api:user:{user_id}"
        except Exception:
            pass
    client = request.client.host if request.client else "unknown"
    return f"api:ip:{client}"


async def global_rate_limit_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    settings = get_settings()
    if not settings.api_rate_limit_enabled or _should_skip(request.url.path):
        return await call_next(request)

    key = _rate_key(request)
    if key is None:
        return await call_next(request)

    async with SessionLocal() as session:
        try:
            await enforce_rate_limit(
                session,
                key,
                limit=settings.api_rate_limit_requests,
                window_seconds=settings.api_rate_limit_window_seconds,
                detail="Слишком много запросов. Попробуйте позже.",
            )
        except HTTPException as exc:
            if exc.status_code == 429:
                request_id = getattr(request.state, "request_id", None)
                user_id = None
                auth = request.headers.get("authorization") or ""
                if auth.lower().startswith("bearer "):
                    try:
                        claims = decode_access_token_claims(auth[7:].strip())
                        sub = claims.get("sub")
                        if isinstance(sub, str):
                            user_id = sub
                    except Exception:
                        pass
                try:
                    await record_audit(
                        session,
                        action="rate_limit.triggered",
                        user_id=user_id,
                        request_id=request_id,
                        metadata={"path": request.url.path},
                    )
                    await session.commit()
                except Exception:
                    await session.rollback()
                return JSONResponse(
                    status_code=429,
                    content={"detail": exc.detail},
                    headers={"Retry-After": str(settings.api_rate_limit_window_seconds)},
                )
            raise

    response = await call_next(request)

    if response.status_code < 500:
        async with SessionLocal() as session:
            try:
                await record_rate_limit_hit(
                    session,
                    key,
                    window_seconds=settings.api_rate_limit_window_seconds,
                )
            except Exception:
                pass

    return response
