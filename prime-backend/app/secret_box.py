"""Authenticated encryption for integration tokens stored in the database."""

from __future__ import annotations

import base64
import binascii
import hashlib

from cryptography.fernet import Fernet, InvalidToken

from .config import get_settings


_PREFIX = "v1:"


def _fernet() -> Fernet:
    raw_key = get_settings().matrix_token_encryption_key.strip()
    if not raw_key:
        raise RuntimeError("MATRIX_TOKEN_ENCRYPTION_KEY is required for Matrix tokens")
    try:
        key = base64.urlsafe_b64decode(raw_key.encode("ascii"))
        if len(key) != 32:
            raise ValueError
        encoded = base64.urlsafe_b64encode(key)
    except (ValueError, UnicodeError, binascii.Error):
        encoded = base64.urlsafe_b64encode(hashlib.sha256(raw_key.encode()).digest())
    return Fernet(encoded)


def encrypt_secret(value: str) -> str:
    return _PREFIX + _fernet().encrypt(value.encode("utf-8")).decode("ascii")


def decrypt_secret(value: str | None) -> str | None:
    if not value:
        return None
    if not value.startswith(_PREFIX):
        return value
    try:
        return _fernet().decrypt(value.removeprefix(_PREFIX).encode("ascii")).decode("utf-8")
    except (InvalidToken, UnicodeError, ValueError):
        return None
