import codecs

import pytest

from app.moderation.lexicon import LEXICON_ALL
from app.moderation.profanity import classify_text


def _rot13(text: str) -> str:
    return codecs.decode(text, "rot13")


@pytest.mark.parametrize(
    "token",
    [
        "shpx",
        "fuvg",
    ],
)
def test_corpus_detects_encoded_profanity(token: str) -> None:
    word = _rot13(token)
    result = classify_text(f"hello {word} world")
    assert result.allowed is False


def test_corpus_allows_scunthorpe() -> None:
    assert classify_text("classic assistant").allowed is True


def test_lexicon_not_empty() -> None:
    assert len(LEXICON_ALL) >= 4
