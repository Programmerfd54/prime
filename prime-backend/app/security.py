from datetime import datetime, timedelta, timezone
from uuid import uuid4
from jose import JWTError, jwt
from passlib.context import CryptContext
from .config import get_settings


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_access_token(user_id: str, session_id: str | None = None) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    # Keep a hard upper bound even when an old environment file still carries
    # the historical 30-day value. The refresh token owns long-lived sessions.
    ttl_minutes = min(settings.access_token_expire_minutes, 15)
    expire = now + timedelta(minutes=ttl_minutes)
    sid = session_id or str(uuid4())
    payload = {
        "sub": user_id,
        "sid": sid,
        "jti": str(uuid4()),
        "iat": now,
        "exp": expire,
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
    }
    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(token: str) -> str | None:
    claims = decode_access_token_claims(token)
    sub = claims.get("sub") if claims else None
    return sub if isinstance(sub, str) else None


def decode_access_token_claims(token: str) -> dict:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
        )
        if not isinstance(payload.get("sub"), str) or not isinstance(payload.get("sid"), str):
            return {}
        return payload
    except JWTError:
        return {}
