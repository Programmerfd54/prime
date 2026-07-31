"""Central gate for moderator-only product surfaces (ops, MFA step-up, appeals ops)."""

from __future__ import annotations

from fastapi import HTTPException, status

from .config import get_settings
from .models import User


def moderator_features_enabled() -> bool:
    return get_settings().moderator_features_enabled


def ensure_moderator_features_enabled() -> None:
    if not moderator_features_enabled():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Функции модератора отключены",
        )


def public_is_moderator(user: User) -> bool:
    if not moderator_features_enabled():
        return False
    return bool(user.is_moderator)
