import inspect

from app.models import GroupMember, WaitingRoomEntry
from app.db import create_db_schema


def test_queue_is_unique_by_user_and_skill() -> None:
    names = {
        constraint.name for constraint in WaitingRoomEntry.__table__.constraints
    }
    assert "uq_waiting_user_skill" in names


def test_queue_migration_removes_legacy_user_only_unique_index() -> None:
    statements = inspect.getsource(create_db_schema)
    assert "DROP INDEX IF EXISTS ix_waiting_room_entries_user_id" in statements
    assert (
        "CREATE INDEX IF NOT EXISTS ix_waiting_room_entries_user_id "
        "ON waiting_room_entries (user_id)"
    ) in statements


def test_group_membership_has_duplicate_guard() -> None:
    names = {constraint.name for constraint in GroupMember.__table__.constraints}
    assert "uq_group_member" in names
