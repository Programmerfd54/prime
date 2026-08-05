import re


NICKNAME_MIN_LEN = 3
NICKNAME_MAX_LEN = 20

# First char: letter, digit, or underscore — not . or -
_NICKNAME_FIRST = r"a-z0-9_\u0401\u0430-\u044f\u0451"
_NICKNAME_BODY = r"a-z0-9_.\-\u0401\u0430-\u044f\u0451"
NICKNAME_RE = re.compile(
    rf"^[{_NICKNAME_FIRST}][{_NICKNAME_BODY}]{{{NICKNAME_MIN_LEN - 1},{NICKNAME_MAX_LEN - 1}}}$"
)

NICKNAME_FORMAT_ERROR = (
    f"Никнейм должен быть {NICKNAME_MIN_LEN}–{NICKNAME_MAX_LEN} символов: "
    "русские или латинские буквы, цифры, точка, дефис или подчёркивание"
)
NICKNAME_PROFANITY_ERROR = "Никнейм содержит недопустимые слова"
DISPLAY_NAME_PROFANITY_ERROR = "Имя содержит недопустимые слова"


def normalize_nickname(value: str | None) -> str:
    nickname = (value or "").strip().lower()
    if nickname.startswith("@"):
        nickname = nickname[1:]
    return nickname


def validate_nickname(value: str | None) -> str:
    nickname = normalize_nickname(value)
    if not NICKNAME_RE.fullmatch(nickname):
        raise ValueError(NICKNAME_FORMAT_ERROR)
    return nickname
