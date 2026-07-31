"""Versioned profanity lexicon (rot13-encoded terms, decoded at import)."""

from __future__ import annotations

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


LEXICON_EN = _decode(_ENCODED_EN)
LEXICON_RU = _decode(_ENCODED_RU)
LEXICON_ALL = LEXICON_EN | LEXICON_RU
