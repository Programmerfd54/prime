import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from pythonjsonlogger.json import JsonFormatter


def configure_logging(level: str) -> None:
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)

    formatter = JsonFormatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s %(pathname)s %(lineno)d"
    )

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)

    file_handler = RotatingFileHandler(
        log_dir / "prime-api.log",
        maxBytes=5_000_000,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level.upper())
    root.addHandler(stream_handler)
    root.addHandler(file_handler)

    logging.getLogger("uvicorn.access").setLevel(logging.INFO)
