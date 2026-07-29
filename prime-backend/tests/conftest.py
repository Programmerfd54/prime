import os

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://prime:prime@localhost:5432/prime",
)
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key")
os.environ.setdefault("MATRIX_ENABLED", "false")
