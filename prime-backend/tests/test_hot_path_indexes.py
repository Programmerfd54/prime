from app.models import (
    ChatMessage,
    DirectMessage,
    GroupMember,
    Notification,
    WaitingRoomEntry,
)


def index_names(model) -> set[str]:
    return {item.name for item in model.__table__.indexes}


def test_hot_path_indexes_are_declared_in_the_model_schema() -> None:
    assert {
        "ix_waiting_skill_region_created",
        "ix_waiting_skill_expand_created",
    } <= index_names(WaitingRoomEntry)
    assert {
        "ix_group_members_user_active_group",
        "ix_group_members_group_active_created",
    } <= index_names(GroupMember)
    assert {"ix_chat_messages_group_created_id"} <= index_names(ChatMessage)
    assert {"ix_direct_messages_conversation_created_id"} <= index_names(DirectMessage)
    assert {
        "ix_notifications_user_created_id",
        "ix_notifications_user_read_created",
    } <= index_names(Notification)
    assert any(
        getattr(item, "name", None) == "uq_chat_message_sender_client_id"
        for item in ChatMessage.__table__.constraints
    )
