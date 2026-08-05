import pytest

from app.nicknames import (
    NICKNAME_FORMAT_ERROR,
    normalize_nickname,
    validate_nickname,
)


def test_nickname_normalized_without_at_and_case() -> None:
    assert normalize_nickname(" @Prime_User ") == "prime_user"
    assert validate_nickname("@Prime.User-1") == "prime.user-1"


def test_cyrillic_nickname_allowed() -> None:
    assert validate_nickname("@праймоля") == "праймоля"
    assert validate_nickname("волна_07") == "волна_07"


@pytest.mark.parametrize("value", ["ab", "bad space", ".starts", "a" * 21])
def test_invalid_nickname_rejected(value: str) -> None:
    with pytest.raises(ValueError, match=NICKNAME_FORMAT_ERROR):
        validate_nickname(value)
