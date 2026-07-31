from .scanner import MediaScanner, ScanResult, ScanVerdict


class NoopScanner(MediaScanner):
    async def scan(self, data: bytes, *, content_type: str) -> ScanResult:
        return ScanResult(verdict=ScanVerdict.CLEAN)
