"""Media scanner interface."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ScanVerdict(str, Enum):
    CLEAN = "CLEAN"
    INFECTED = "REJECTED"
    ERROR = "ERROR"


@dataclass(frozen=True)
class ScanResult:
    verdict: ScanVerdict
    detail: str = ""


class MediaScanner:
    async def scan(self, data: bytes, *, content_type: str) -> ScanResult:
        raise NotImplementedError
