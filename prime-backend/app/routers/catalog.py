"""catalog routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import mimetypes
from pathlib import Path as FsPath
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_user
from ..matrix import (
    create_room,
    download_media,
    ensure_matrix_user,
    mxc_to_http,
    send_room_message,
    upload_media,
)
from ..models import (
    ChatMessage,
    ChatMessageReaction,
    CustomSkill,
    DirectConversationRead,
    DirectMessage,
    FriendRequest,
    Friendship,
    Group,
    GroupCheckIn,
    GroupMember,
    HabitReport,
    PrimeEvent,
    ReportAttachment,
    User,
    WaitingRoomEntry,
    utcnow,
)
from ..regions import REGIONS
from ..schemas import GroupCheckInRequest, HealthResponse, parse_privacy_settings
from ..skills_catalog import SKILLS, skill_name
from ..metrics_engine import achievement_awarded_at
from ..team_day import team_completed_dates
from . import group_service as svc
from .group_service import (
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

router = APIRouter(tags=["catalog"])

@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/regions")
async def regions() -> dict:
    return {"regions": list(REGIONS)}


@router.get("/media/{server_name}/{media_id}")
async def matrix_media(
    server_name: str,
    media_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    user = await ensure_matrix_user(user, session)
    try:
        content, content_type = await download_media(user, server_name, media_id)
    except Exception as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Медиафайл не найден",
        ) from error
    return Response(content=content, media_type=content_type)


@router.get("/skills")
async def skills(
    category: str | None = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    items = list(SKILLS)
    custom_rows = await session.execute(
        select(CustomSkill).where(CustomSkill.user_id == user.id).order_by(CustomSkill.created_at.asc())
    )
    for row in custom_rows.scalars().all():
        items.append(
            {
                "id": row.id,
                "name": row.name,
                "description": row.description,
                "category": "custom",
                "icon": "auto_awesome",
                "is_custom": True,
            }
        )
    if category:
        return [item for item in items if item.get("category") == category]
    return items


class CreateCustomSkillRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=2000)


@router.post("/skills/custom", status_code=201)
async def create_custom_skill(
    payload: CreateCustomSkillRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if not user.can_create_custom_skills:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Создание своих привычек откроется после 10 Праймов",
        )
    skill = CustomSkill(
        user_id=user.id,
        name=payload.name.strip(),
        description=payload.description.strip(),
    )
    session.add(skill)
    await session.commit()
    await session.refresh(skill)
    return {
        "id": skill.id,
        "name": skill.name,
        "description": skill.description,
        "category": "custom",
        "icon": "auto_awesome",
        "is_custom": True,
    }


@router.get("/achievements")
async def achievements(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    successful_days = user.successful_days
    completed_dates = sorted(await team_completed_dates(session, user.id))
    items = [
        {
            "id": "student",
            "code": "student",
            "name": "Ученик",
            "required_days": 30,
            "description": "Минимальный базовый цикл закрепления привычки пройден",
            "icon": "school",
        },
        {
            "id": "master",
            "code": "master",
            "name": "Мастер",
            "required_days": 90,
            "description": "Устойчивая поведенческая трансформация",
            "icon": "workspace_premium",
        },
        {
            "id": "mentor",
            "code": "mentor",
            "name": "Наставник",
            "required_days": 365,
            "description": "Год стабильного личностного роста и дисциплины",
            "icon": "psychology",
        },
        {
            "id": "prime_mentor",
            "code": "prime_mentor",
            "name": "Прайм-наставник",
            "required_days": 1000,
            "description": "Лидерские качества и эталонная осознанность",
            "icon": "military_tech",
        },
        {
            "id": "ideologist",
            "code": "ideologist",
            "name": "Идеолог",
            "required_days": 10000,
            "description": "Абсолютное слияние философии ПРАЙМ с образом жизни",
            "icon": "auto_awesome",
        },
    ]
    return [
        {
            **item,
            "unlocked": successful_days >= item["required_days"],
            "awarded_at": achievement_awarded_at(
                required_days=item["required_days"],
                unlocked=successful_days >= item["required_days"],
                completed_dates=completed_dates,
                fallback=user.created_at,
            ),
            "progress_days": min(successful_days, item["required_days"]),
        }
        for item in items
    ]


