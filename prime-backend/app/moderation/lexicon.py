"""Versioned profanity lexicon (rot13-encoded terms, decoded at import)."""

from __future__ import annotations

import base64
import codecs

POLICY_VERSION = "1.0"
DETECTOR_VERSION = "1.0"

# Rot13 keeps terms out of plain-text search; decoded only in memory.
_ENCODED_EN = [
    "shpx",
    "ovgpu",
    "nffubyr",
    "qhzoohf",
    "fuvg",
]
_ENCODED_RU = [
    "kbl",
    "cyng",
    "fcbeyb",
    "qrovy",
    "fhyx",
]

# Cyrillic forms (base64) — latin translit lexicon alone misses native script input.
_ENCODED_RU_CYRL = [
    "0YXRg9C5",
    "0LHQu9GP0YLRjA==",
    "0LHQu9GP",
    "0L/QuNC30LTQsA==",
    "0YHRg9C60LA=",
    "0LXQsdCw0YLRjA==",
    "0ZHQsQ==",
    "0L/QuNC00L7RgA==",
    "0LzRg9C00LDQug==",
]

# Allowlist tokens that must not trigger substring false positives.
ALLOWLIST = frozenset(
    {
        "scunthorpe",
        "classic",
        "assistant",
        "passion",
        "grape",
        "document",
    }
)


def _decode(items: list[str]) -> frozenset[str]:
    return frozenset(codecs.decode(item, "rot13") for item in items)


def _decode_b64(items: list[str]) -> frozenset[str]:
    return frozenset(base64.b64decode(item).decode("utf-8") for item in items)


LEXICON_EN = _decode(_ENCODED_EN)
LEXICON_RU_LATIN = _decode(_ENCODED_RU)
LEXICON_RU_CYRL = _decode_b64(_ENCODED_RU_CYRL)
LEXICON_RU = LEXICON_RU_LATIN | LEXICON_RU_CYRL
LEXICON_ALL = LEXICON_EN | LEXICON_RU
