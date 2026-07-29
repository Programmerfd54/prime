import pytest

from app.nicknames import normalize_nickname, validate_nickname


def test_nickname_normalized_without_at_and_case() -> None:
    assert normalize_nickname(" @Prime_User ") == "prime_user"
    assert validate_nickname("@Prime.User-1") == "prime.user-1"


@pytest.mark.parametrize("value", ["ab", "иван", "bad space", ".starts"])
def test_invalid_nickname_rejected(value: str) -> None:
    with pytest.raises(ValueError):
        validate_nickname(value)
