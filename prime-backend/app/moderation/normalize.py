"""Unicode normalization and evasion-resistant preprocessing."""

from __future__ import annotations

import re
import unicodedata

_ZERO_WIDTH = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]")
_REPEAT = re.compile(r"(.)\1{3,}")
_SPLITTER = re.compile(r"[\s.\-_·•*,!@#$%^&*()+={}\[\]|\\/:;\"'<>?`~]+")

# Latin letters that look like Cyrillic and vice versa.
_HOMOGLYPHS = str.maketrans(
    {
        "а": "a",
        "е": "e",
        "о": "o",
        "р": "p",
        "с": "c",
        "у": "y",
        "х": "x",
        "А": "a",
        "В": "b",
        "Е": "e",
        "К": "k",
        "М": "m",
        "Н": "h",
        "О": "o",
        "Р": "p",
        "С": "c",
        "Т": "t",
        "Х": "x",
    }
)

_LEET = str.maketrans(
    {
        "0": "o",
        "1": "i",
        "3": "e",
        "4": "a",
        "5": "s",
        "7": "t",
        "@": "a",
        "$": "s",
    }
)


def normalize_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", value or "")
    text = _ZERO_WIDTH.sub("", text)
    text = text.translate(_HOMOGLYPHS)
    text = text.translate(_LEET)
    text = text.lower()
    text = _SPLITTER.sub(" ", text)
    text = _REPEAT.sub(r"\1\1", text)
    return " ".join(text.split())


def tokenize(value: str) -> list[str]:
    normalized = normalize_text(value)
    if not normalized:
        return []
    return normalized.split(" ")


def compact(value: str) -> str:
    return normalize_text(value).replace(" ", "")
