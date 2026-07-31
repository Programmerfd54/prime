"""Profanity classification with evasion resistance."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from enum import Enum

from .lexicon import ALLOWLIST, DETECTOR_VERSION, LEXICON_ALL, LEXICON_EN, LEXICON_RU, POLICY_VERSION
from .normalize import compact, normalize_text, tokenize


class ConfidenceBand(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class ProfanityLanguage(str, Enum):
    EN = "EN"
    RU = "RU"
    MIXED = "MIXED"


@dataclass(frozen=True)
class ClassificationResult:
    allowed: bool
    confidence: ConfidenceBand
    language: ProfanityLanguage | None
    category: str | None
    normalized_hash: str
    policy_version: str = POLICY_VERSION
    detector_version: str = DETECTOR_VERSION


def _hash_normalized(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _match_token(token: str, lexicon: frozenset[str]) -> bool:
    if not token or token in ALLOWLIST:
        return False
    if token in lexicon:
        return True
    stripped = token.strip(".,!?;:")
    return stripped in lexicon and stripped not in ALLOWLIST


def _compact_match(text: str, lexicon: frozenset[str]) -> bool:
    c = compact(text)
    if not c or c in ALLOWLIST:
        return False
    for term in lexicon:
        if term in ALLOWLIST:
            continue
        if term in c and len(term) >= 4:
            return True
    return False


def classify_text(text: str) -> ClassificationResult:
    normalized = normalize_text(text)
    normalized_hash = _hash_normalized(normalized)
    if not normalized:
        return ClassificationResult(
            allowed=True,
            confidence=ConfidenceBand.LOW,
            language=None,
            category=None,
            normalized_hash=normalized_hash,
        )

    tokens = tokenize(text)
    en_hits = sum(1 for t in tokens if _match_token(t, LEXICON_EN))
    ru_hits = sum(1 for t in tokens if _match_token(t, LEXICON_RU))

    if en_hits == 0 and ru_hits == 0:
        if _compact_match(text, LEXICON_ALL):
            return ClassificationResult(
                allowed=False,
                confidence=ConfidenceBand.HIGH,
                language=ProfanityLanguage.MIXED,
                category="PROFANITY_MIXED",
                normalized_hash=normalized_hash,
            )
        return ClassificationResult(
            allowed=True,
            confidence=ConfidenceBand.LOW,
            language=None,
            category=None,
            normalized_hash=normalized_hash,
        )

    if en_hits and ru_hits:
        lang = ProfanityLanguage.MIXED
        reason = "PROFANITY_MIXED"
    elif ru_hits:
        lang = ProfanityLanguage.RU
        reason = "PROFANITY_RU"
    else:
        lang = ProfanityLanguage.EN
        reason = "PROFANITY_EN"

    total = en_hits + ru_hits
    if total >= 1 and any(len(t) <= 3 for t in tokens if _match_token(t, LEXICON_ALL)):
        return ClassificationResult(
            allowed=False,
            confidence=ConfidenceBand.MEDIUM,
            language=lang,
            category=reason,
            normalized_hash=normalized_hash,
        )

    return ClassificationResult(
        allowed=False,
        confidence=ConfidenceBand.HIGH,
        language=lang,
        category=reason,
        normalized_hash=normalized_hash,
    )
