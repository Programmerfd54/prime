import re


NICKNAME_RE = re.compile(r"^[a-z0-9_][a-z0-9_.-]{2,31}$")


def normalize_nickname(value: str | None) -> str:
    nickname = (value or "").strip().lower()
    if nickname.startswith("@"):
        nickname = nickname[1:]
    return nickname


def validate_nickname(value: str | None) -> str:
    nickname = normalize_nickname(value)
    if not NICKNAME_RE.fullmatch(nickname):
        raise ValueError(
            "Никнейм должен быть 3–32 символа: латинские буквы, цифры, точка, дефис или подчёркивание"
        )
    return nickname
