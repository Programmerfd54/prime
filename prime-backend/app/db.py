from collections.abc import AsyncGenerator
import hashlib
from pathlib import Path
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import text
from .config import get_settings


class Base(DeclarativeBase):
    pass


settings = get_settings()
_engine_options = {"pool_pre_ping": True}
if not settings.database_url.startswith("sqlite"):
    _engine_options.update(
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_timeout=settings.db_pool_timeout_seconds,
        pool_recycle=settings.db_pool_recycle_seconds,
    )
    if settings.database_use_pgbouncer:
        _engine_options["connect_args"] = {
            "statement_cache_size": 0,
            "prepared_statement_cache_size": 0,
        }
engine = create_async_engine(settings.database_url, **_engine_options)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session


def _split_sql_statements(sql: str) -> list[str]:
    """Split a migration file into individual statements for PostgreSQL drivers."""
    statements: list[str] = []
    current: list[str] = []
    for line in sql.splitlines():
        stripped = line.strip()
        if stripped.startswith("--"):
            continue
        current.append(line)
        if stripped.endswith(";"):
            statement = "\n".join(current).strip()
            if statement.endswith(";"):
                statement = statement[:-1].strip()
            if statement:
                statements.append(statement)
            current = []
    remainder = "\n".join(current).strip()
    if remainder:
        statements.append(remainder.rstrip(";").strip())
    return statements


async def _apply_forward_migrations(conn) -> None:
    """Apply checked-in PostgreSQL migrations after the legacy bootstrap.

    The project predates Alembic and still needs the idempotent bootstrap above
    for existing installations.  This ledger makes new changes observable and
    prevents silently running a changed migration twice.
    """
    if conn.dialect.name != "postgresql":
        return
    await conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                checksum VARCHAR(64) NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
    )
    migration_dir = Path(__file__).resolve().parents[1] / "migrations"
    if not migration_dir.exists():
        return
    applied = {
        row.version: row.checksum
        for row in (await conn.execute(text("SELECT version, checksum FROM schema_migrations"))).all()
    }
    for path in sorted(migration_dir.glob("[0-9]*_*.sql")):
        version = path.name
        sql = path.read_text(encoding="utf-8")
        checksum = hashlib.sha256(sql.encode("utf-8")).hexdigest()
        previous_checksum = applied.get(version)
        if previous_checksum is not None:
            if previous_checksum != checksum:
                raise RuntimeError(f"Migration checksum mismatch: {version}")
            continue
        for statement in _split_sql_statements(sql):
            await conn.exec_driver_sql(statement)
        await conn.execute(
            text(
                "INSERT INTO schema_migrations (version, checksum) "
                "VALUES (:version, :checksum)"
            ),
            {"version": version, "checksum": checksum},
        )


async def create_db_schema() -> None:
    from . import models  # noqa: F401

    async with engine.begin() as conn:
        if conn.dialect.name == "postgresql":
            # Every Gunicorn worker runs the application lifespan.  On a
            # brand-new database, concurrent metadata.create_all() calls can
            # race while PostgreSQL is creating table types.  A transaction-
            # scoped advisory lock serializes bootstrap/migrations and is
            # released automatically on commit or rollback.
            await conn.execute(
                text("SELECT pg_advisory_xact_lock(:lock_id)"),
                {"lock_id": 717342370665433},
            )
        await conn.run_sync(Base.metadata.create_all)
        migrations = (
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS matrix_access_token TEXT",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS nickname VARCHAR(32)",
            """
            UPDATE users
            SET nickname = lower('user' || left(replace(id, '-', ''), 28))
            WHERE nickname IS NULL OR nickname = ''
            """,
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_nickname ON users (lower(nickname))",
            "DROP INDEX IF EXISTS ix_users_public_uuid",
            "ALTER TABLE users DROP COLUMN IF EXISTS public_uuid",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS region_code VARCHAR(8)",
            "CREATE INDEX IF NOT EXISTS ix_users_region_code ON users (region_code)",
            "ALTER TABLE waiting_room_entries DROP CONSTRAINT IF EXISTS waiting_room_entries_user_id_key",
            "DROP INDEX IF EXISTS ix_waiting_room_entries_user_id",
            "ALTER TABLE waiting_room_entries ADD COLUMN IF NOT EXISTS region_code VARCHAR(8)",
            "ALTER TABLE waiting_room_entries ADD COLUMN IF NOT EXISTS allow_other_regions BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE waiting_room_entries ADD COLUMN IF NOT EXISTS expansion_offered_at TIMESTAMPTZ",
            "UPDATE waiting_room_entries w SET region_code = u.region_code FROM users u WHERE w.user_id = u.id AND w.region_code IS NULL",
            "CREATE INDEX IF NOT EXISTS ix_waiting_room_entries_region_code ON waiting_room_entries (region_code)",
            "CREATE INDEX IF NOT EXISTS ix_waiting_room_entries_user_id ON waiting_room_entries (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_waiting_room_entries_allow_other_regions ON waiting_room_entries (allow_other_regions)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_waiting_user_skill ON waiting_room_entries (user_id, skill_id)",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS region_code VARCHAR(8)",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_cross_region BOOLEAN NOT NULL DEFAULT FALSE",
            "CREATE INDEX IF NOT EXISTS ix_groups_region_code ON groups (region_code)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_group_member ON group_members (group_id, user_id)",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS filename VARCHAR(500)",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS content_type VARCHAR(160)",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS size_bytes BIGINT",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS duration_ms INTEGER",
            "ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS thumbnail_url TEXT",
            """
            CREATE TABLE IF NOT EXISTS chat_message_reactions (
                id VARCHAR(36) PRIMARY KEY,
                message_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                emoji VARCHAR(16) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT now(),
                CONSTRAINT uq_chat_message_reaction UNIQUE (message_id, user_id, emoji)
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_chat_message_reactions_message_id ON chat_message_reactions (message_id)",
            "CREATE INDEX IF NOT EXISTS ix_chat_message_reactions_user_id ON chat_message_reactions (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_chat_message_reactions_emoji ON chat_message_reactions (emoji)",
            "ALTER TABLE habit_reports ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'ready'",
            "CREATE INDEX IF NOT EXISTS ix_habit_reports_status ON habit_reports (status)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_daily_report ON habit_reports (group_id, user_id, report_date)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_friend_request_pair ON friend_requests (requester_user_id, addressee_user_id)",
            "CREATE INDEX IF NOT EXISTS ix_friend_requests_addressee_status ON friend_requests (addressee_user_id, status)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_friendship_pair ON friendships (user_low_id, user_high_id)",
            "CREATE INDEX IF NOT EXISTS ix_friendships_user_low_id ON friendships (user_low_id)",
            "CREATE INDEX IF NOT EXISTS ix_friendships_user_high_id ON friendships (user_high_id)",
            "CREATE INDEX IF NOT EXISTS ix_direct_messages_conversation_key_created_at ON direct_messages (conversation_key, created_at)",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS msgtype VARCHAR(80) NOT NULL DEFAULT 'm.text'",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS url TEXT",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS filename VARCHAR(500)",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS content_type VARCHAR(160)",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS size_bytes BIGINT",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS reply_to_id VARCHAR(36)",
            "CREATE INDEX IF NOT EXISTS ix_direct_messages_reply_to_id ON direct_messages (reply_to_id)",
            "ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS client_id VARCHAR(64)",
            # NULLs are distinct in Postgres unique indexes, so messages without a
            # client_id (older clients) are unaffected by this constraint.
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_direct_messages_sender_client_id ON direct_messages (sender_user_id, client_id)",
            """
            CREATE TABLE IF NOT EXISTS direct_message_reactions (
                id VARCHAR(36) PRIMARY KEY,
                message_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                emoji VARCHAR(16) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT now(),
                CONSTRAINT uq_direct_message_reaction UNIQUE (message_id, user_id, emoji)
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_direct_message_reactions_message_id ON direct_message_reactions (message_id)",
            "CREATE INDEX IF NOT EXISTS ix_direct_message_reactions_user_id ON direct_message_reactions (user_id)",
            """
            CREATE TABLE IF NOT EXISTS direct_conversation_reads (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                friend_id VARCHAR(36) NOT NULL,
                last_read_at TIMESTAMPTZ DEFAULT now(),
                CONSTRAINT uq_direct_conversation_read UNIQUE (user_id, friend_id)
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_direct_conversation_reads_user_id ON direct_conversation_reads (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_direct_conversation_reads_friend_id ON direct_conversation_reads (friend_id)",
            """
            CREATE TABLE IF NOT EXISTS password_reset_tokens (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                token_hash VARCHAR(64) NOT NULL UNIQUE,
                expires_at TIMESTAMPTZ NOT NULL,
                used_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_password_reset_tokens_user_id ON password_reset_tokens (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_password_reset_tokens_expires_at ON password_reset_tokens (expires_at)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_settings TEXT NOT NULL DEFAULT '{}'",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_preferences TEXT NOT NULL DEFAULT '{}'",
            """
            CREATE TABLE IF NOT EXISTS user_skill_favorites (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                skill_id VARCHAR(120) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT now(),
                CONSTRAINT uq_user_skill_favorite UNIQUE (user_id, skill_id)
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_user_skill_favorites_user_id ON user_skill_favorites (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_user_skill_favorites_skill_id ON user_skill_favorites (skill_id)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ",
            "ALTER TABLE waiting_room_entries ADD COLUMN IF NOT EXISTS pair_code VARCHAR(32)",
            "CREATE INDEX IF NOT EXISTS ix_waiting_room_entries_pair_code ON waiting_room_entries (pair_code)",
            "ALTER TABLE waiting_room_entries ADD COLUMN IF NOT EXISTS pair_start_confirmed_at TIMESTAMPTZ",
            """
            CREATE TABLE IF NOT EXISTS notifications (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                type VARCHAR(32) NOT NULL,
                title VARCHAR(200) NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                payload TEXT NOT NULL DEFAULT '{}',
                read_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_type ON notifications (type)",
            "CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications (user_id, read_at)",
            """
            CREATE TABLE IF NOT EXISTS device_tokens (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                platform VARCHAR(16) NOT NULL,
                token VARCHAR(512) NOT NULL UNIQUE,
                created_at TIMESTAMPTZ DEFAULT now(),
                updated_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id ON device_tokens (user_id)",
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_device_tokens_token ON device_tokens (token)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS streak_shields INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS shield_pending BOOLEAN NOT NULL DEFAULT FALSE",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE",
            # The DEFAULT grandfathers accounts that existed before email
            # confirmation shipped; dropping it right away keeps every new
            # signup unverified until it confirms the code.
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ DEFAULT now()",
            "ALTER TABLE users ALTER COLUMN email_verified_at DROP DEFAULT",
            """
            CREATE TABLE IF NOT EXISTS email_verification_codes (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                code_hash VARCHAR(64) NOT NULL,
                expires_at TIMESTAMPTZ NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                used_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_email_verification_codes_user_id ON email_verification_codes (user_id)",
            "CREATE INDEX IF NOT EXISTS ix_email_verification_codes_expires_at ON email_verification_codes (expires_at)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS marketing_emails_opt_in BOOLEAN NOT NULL DEFAULT TRUE",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS marketing_emails_unsubscribed_at TIMESTAMPTZ",
            """
            CREATE TABLE IF NOT EXISTS custom_skills (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                name VARCHAR(120) NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                created_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_custom_skills_user_id ON custom_skills (user_id)",
            """
            CREATE TABLE IF NOT EXISTS group_days (
                id VARCHAR(36) PRIMARY KEY,
                group_id VARCHAR(36) NOT NULL,
                day_date DATE NOT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'pending',
                ready_count INTEGER NOT NULL DEFAULT 0,
                member_count INTEGER NOT NULL DEFAULT 0,
                completed_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT now(),
                updated_at TIMESTAMPTZ DEFAULT now()
            )
            """,
            "CREATE INDEX IF NOT EXISTS ix_group_days_group_id ON group_days (group_id)",
            "CREATE INDEX IF NOT EXISTS ix_group_days_day_date ON group_days (day_date)",
            "CREATE INDEX IF NOT EXISTS ix_group_days_status ON group_days (status)",
            """
            CREATE UNIQUE INDEX IF NOT EXISTS uq_group_day
            ON group_days (group_id, day_date)
            """,
            # Grandfather historical ready reports as complete team days so
            # existing users keep primes/streaks under the new rule.
            """
            INSERT INTO group_days (
                id, group_id, day_date, status, ready_count, member_count,
                completed_at, created_at, updated_at
            )
            SELECT
                md5(hr.group_id || ':' || hr.report_date::text),
                hr.group_id,
                hr.report_date,
                'complete',
                COUNT(hr.id)::int,
                GREATEST(
                    COUNT(hr.id)::int,
                    COALESCE((
                        SELECT COUNT(*)::int FROM group_members gm
                        WHERE gm.group_id = hr.group_id AND gm.active IS TRUE
                    ), 0)
                ),
                (hr.report_date::timestamp AT TIME ZONE 'UTC'),
                now(),
                now()
            FROM habit_reports hr
            WHERE hr.status = 'ready'
              AND NOT EXISTS (
                  SELECT 1 FROM group_days gd
                  WHERE gd.group_id = hr.group_id AND gd.day_date = hr.report_date
              )
            GROUP BY hr.group_id, hr.report_date
            ON CONFLICT DO NOTHING
            """,
        )
        for statement in migrations:
            await conn.exec_driver_sql(statement)
        await _apply_forward_migrations(conn)
