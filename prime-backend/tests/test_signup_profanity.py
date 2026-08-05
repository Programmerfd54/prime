import pytest

from app.moderation.profanity import classify_text


@pytest.mark.parametrize(
    "value",
    [
        "хуй",
        "блять",
        "пизда",
        "сука",
        "fuck",
        "shit",
    ],
)
def test_signup_text_blocks_profanity(value: str) -> None:
    result = classify_text(value)
    assert result.allowed is False


def test_signup_text_allows_normal_name() -> None:
    assert classify_text("Даниил").allowed is True
    assert classify_text("shadow").allowed is True
