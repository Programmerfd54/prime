"""Signed unsubscribe links embedded in outgoing mail."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

from .config import get_settings

# Letter ids identify the campaign / template in the unsubscribe link.
LETTER_SIGNUP_VERIFICATION = "signup_verification"
LETTER_PASSWORD_RESET = "password_reset"
LETTER_MARKETING = "marketing"


@dataclass(frozen=True)
class UnsubscribePayload:
    user_id: str
    email: str
    letter: str

    def as_dict(self) -> dict[str, str]:
        return {
            "uid": self.user_id,
            "email": self.email.strip().lower(),
            "letter": self.letter,
        }


def _sign(data: str) -> str:
    secret = get_settings().jwt_secret_key.encode("utf-8")
    return hmac.new(secret, data.encode("utf-8"), hashlib.sha256).hexdigest()[:32]


def create_unsubscribe_token(*, user_id: str, email: str, letter: str) -> str:
    payload = UnsubscribePayload(user_id=user_id, email=email, letter=letter)
    raw = json.dumps(payload.as_dict(), separators=(",", ":"), ensure_ascii=False)
    data = base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii").rstrip("=")
    return f"{data}.{_sign(data)}"


def parse_unsubscribe_token(token: str) -> UnsubscribePayload | None:
    try:
        data, signature = token.rsplit(".", 1)
        if not hmac.compare_digest(_sign(data), signature):
            return None
        padding = "=" * (-len(data) % 4)
        raw = base64.urlsafe_b64decode(f"{data}{padding}")
        parsed: dict[str, Any] = json.loads(raw.decode("utf-8"))
        user_id = str(parsed.get("uid", "")).strip()
        email = str(parsed.get("email", "")).strip().lower()
        letter = str(parsed.get("letter", "")).strip()
        if not user_id or not email or not letter:
            return None
        return UnsubscribePayload(user_id=user_id, email=email, letter=letter)
    except (ValueError, json.JSONDecodeError, UnicodeDecodeError):
        return None


def build_unsubscribe_url(*, user_id: str, email: str, letter: str) -> str:
    settings = get_settings()
    base = settings.public_api_base_url.rstrip("/")
    token = create_unsubscribe_token(user_id=user_id, email=email, letter=letter)
    return f"{base}/email/unsubscribe?token={quote(token, safe='')}"


def letter_label(letter: str) -> str:
    return {
        LETTER_SIGNUP_VERIFICATION: "Подтверждение регистрации",
        LETTER_PASSWORD_RESET: "Восстановление пароля",
        LETTER_MARKETING: "Новости и советы ПРАЙМ",
    }.get(letter, "Рассылка ПРАЙМ")
