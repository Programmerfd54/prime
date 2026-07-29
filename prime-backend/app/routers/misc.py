"""Backward-compatible facade over split routers."""
from fastapi import APIRouter

from ..matrix import create_room, send_room_message  # noqa: F401 — patched in tests
from ..skills_catalog import SKILLS, skill_name
from . import group_service as _gs
from .group_service import (  # noqa: F401
    ALLOWED_DIRECT_DOCUMENT_TYPES,
    ALLOWED_DOCUMENT_TYPES,
    ALLOWED_MEDIA_PREFIXES,
    ALLOWED_REACTION_EMOJIS,
    MAX_DIRECT_FILE_BYTES,
    MAX_DIRECT_IMAGE_BYTES,
    MAX_MEDIA_BYTES,
    MIN_GROUP_MEMBERS,
    PARTIAL_GROUP_START_DELAY,
    REGION_EXPANSION_DELAY,
    WAITING_ROOM_SIZE,
    _activate_if_ready,
    _are_friends,
    _chat_message_payload,
    _chat_payloads,
    _create_friend_request_for_addressee,
    _create_group,
    _create_group_chat_message,
    _current_group_for_user,
    _direct_chat_inbox_items,
    _direct_conversation_key,
    _direct_message_payload,
    _fill_group_vacancies,
    _friend_ids_for_user,
    _friend_request_payload,
    _friendship_pair,
    _group_for_user_skill,
    _group_intro_body,
    _group_payload,
    _mark_direct_chat_read,
    _maybe_match_waiting_room,
    _public_user_payload,
    _reaction_payloads,
    _report_payload,
    _require_active_group,
    _sync_user_daily_progress,
    _team_pulse,
    _user_membership,
    _user_payload,
    waiting_room_payload,
)
from .catalog import achievements, health, matrix_media, regions, router as catalog_router, skills
from .social import (
    cancel_friend_request,
    create_friend_request,
    direct_chat_upload_media,
    direct_messages,
    find_user_by_nickname,
    friend_requests,
    friends,
    list_direct_chats,
    mark_direct_chat_read,
    respond_friend_request,
    router as social_router,
    send_direct_message,
)
from .notifications import (
    list_notifications as notifications,
    router as notifications_router,
)
from .waiting_room import (
    expand_waiting_room_search,
    join_waiting_room,
    leave_waiting_room,
    router as waiting_room_router,
    waiting_room,
    waiting_rooms,
)
from .groups import (
    accept_rules_alias,
    assemble_test_team,
    confirm_participation_alias,
    current_group,
    get_group,
    group_check_in,
    groups,
    intro_change,
    intro_continue,
    router as groups_router,
    rules_accept,
    vote,
)
from .chat import (
    chat_messages,
    chat_send_image,
    chat_send_message_new,
    chat_send_message_old,
    chat_sync,
    chat_toggle_reaction,
    chat_upload_media,
    router as chat_router,
)
from .reports import calendar, calendar_all, create_report, report_upload_media, router as reports_router

# Tests monkeypatch matrix helpers on this module; forward attribute sets to service.
def __getattr__(name: str):
    return getattr(_gs, name)


router = APIRouter(tags=["misc"])
router.include_router(catalog_router)
router.include_router(social_router)
router.include_router(notifications_router)
router.include_router(waiting_room_router)
router.include_router(groups_router)
router.include_router(chat_router)
router.include_router(reports_router)
