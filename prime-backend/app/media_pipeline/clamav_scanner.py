import asyncio
import socket

from ..config import get_settings
from .scanner import MediaScanner, ScanResult, ScanVerdict


class ClamAvScanner(MediaScanner):
    async def scan(self, data: bytes, *, content_type: str) -> ScanResult:
        settings = get_settings()

        def _scan() -> ScanResult:
            try:
                with socket.create_connection(
                    (settings.clamav_host, settings.clamav_port),
                    timeout=5,
                ) as sock:
                    sock.sendall(b"zINSTREAM\0")
                    size = len(data).to_bytes(4, "big")
                    sock.sendall(size + data + b"\0")
                    response = sock.recv(4096).decode("utf-8", errors="ignore")
                if "FOUND" in response:
                    return ScanResult(verdict=ScanVerdict.INFECTED, detail="malware_detected")
                if "OK" in response:
                    return ScanResult(verdict=ScanVerdict.CLEAN)
                return ScanResult(verdict=ScanVerdict.ERROR, detail=response[:200])
            except OSError as exc:
                return ScanResult(verdict=ScanVerdict.ERROR, detail=str(exc))

        return await asyncio.to_thread(_scan)
