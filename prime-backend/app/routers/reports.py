"""reports routes — split from misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import mimetypes
from pathlib import Path as FsPath
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, Response, UploadFile, status
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import get_current_user
from ..media import read_upload
from ..media_scope import validate_media_url_for_scope
from ..moderation import ModerationError, check_social_write_allowed, moderate_text_before_publish
from ..moderation.pipeline import moderation_http_error
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
from ..metrics_engine import streak_snapshot, sync_group_member_streak
from ..notifications import create_notification, notify_group_members as push_group_members
from ..nicknames import normalize_nickname
from ..group_progress import compute_team_milestones, compute_team_recap, first_ready_report_date
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
    _bump_group_revision,
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
    _notify_group_members,
    notify_unlocked_milestones,
    _public_user_payload,
    _reaction_payloads,
    _report_payload,
    _report_payloads,
    _require_active_group,
    _sync_user_daily_progress,
    _team_pulse,
    _user_membership,
    _user_payload,
    waiting_room_payload,
)

router = APIRouter(tags=["reports"])

@router.post("/reports/upload")
async def report_upload_media(
    file: UploadFile = File(...),
    group_id: str = Form(...),
    request: Request = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _require_active_group(session, group_id, user)
    if request is not None:
        from ..rate_limit import enforce as enforce_rate_limit
        from ..rate_limit import record_failure as record_rate_limit_failure
        settings = get_settings()
        keys = (
            f"upload:report:user:{user.id}",
            f"upload:report:ip:{request.client.host if request.client else 'unknown'}",
        )
        for key in keys:
            await enforce_rate_limit(session, key, limit=settings.upload_rate_limit_attempts, window_seconds=settings.upload_rate_limit_window_seconds, detail="Слишком много загрузок. Попробуйте позже.")
        for key in keys:
            await record_rate_limit_failure(session, key, window_seconds=settings.upload_rate_limit_window_seconds)
    user = await ensure_matrix_user(user, session)
    declared_type = (file.content_type or "").lower()
    read_limit = MAX_DIRECT_IMAGE_BYTES if declared_type.startswith("image/") else MAX_MEDIA_BYTES
    content, content_type, filename = await read_upload(
        file,
        max_bytes=read_limit,
        max_image_bytes=MAX_DIRECT_IMAGE_BYTES,
        allow_types=set(),
    )
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл пустой")
    if len(content) > MAX_MEDIA_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Файл больше 100 МБ")
    if not content_type.startswith(ALLOWED_MEDIA_PREFIXES):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для отчёта можно загрузить фото, видео, аудио или видеокружок",
        )
    media_url = await upload_media(user, session, filename, content_type, content, "group", group_id)
    await session.commit()
    return {
        "storage_url": media_url,
        "url": mxc_to_http(media_url),
        "filename": filename,
        "content_type": content_type,
        "size_bytes": len(content),
    }


@router.get("/reports/calendar")
async def calendar(
    group_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    membership = await _user_membership(session, group_id, user.id)
    reports = (
        await session.execute(
            select(HabitReport)
            .where(HabitReport.group_id == group_id, HabitReport.user_id == user.id)
            .order_by(HabitReport.report_date.asc())
        )
    ).scalars().all()
    return {
        "group_id": group_id,
        "days": await _report_payloads(session, reports),
        "today": date.today().isoformat(),
        "tracking_start_date": membership.created_at.date().isoformat(),
    }


@router.get("/reports/calendar/all")
async def calendar_all(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    limit: int = Query(default=365, ge=1, le=730),
) -> dict:
    if not isinstance(limit, int):
        limit = 365
    first_membership_at = await session.scalar(
        select(func.min(GroupMember.created_at)).where(GroupMember.user_id == user.id)
    )
    reports = (
        await session.execute(
            select(HabitReport)
            .where(HabitReport.user_id == user.id)
            .order_by(HabitReport.report_date.asc(), HabitReport.created_at.asc())
            .limit(limit + 1)
        )
    ).scalars().all()
    has_more = len(reports) > limit
    reports = reports[:limit]
    group_ids = {report.group_id for report in reports}
    groups_by_id: dict[str, Group] = {}
    if group_ids:
        groups = (await session.execute(select(Group).where(Group.id.in_(group_ids)))).scalars().all()
        groups_by_id = {group.id: group for group in groups}

    reports_by_date: dict[date, list[HabitReport]] = {}
    for report in reports:
        reports_by_date.setdefault(report.report_date, []).append(report)

    days = []
    from ..team_day import team_completed_dates, team_pending_dates

    completed_team_dates = await team_completed_dates(session, user.id)
    pending_team_dates = await team_pending_dates(session, user.id)

    for report_date, day_reports in reports_by_date.items():
        ready_reports = [report for report in day_reports if report.status == "ready"]
        personal_ready = bool(ready_reports)
        team_complete = report_date in completed_team_dates
        representative = ready_reports[-1] if ready_reports else day_reports[-1]
        report_items = [
            {
                "id": report.id,
                "group_id": report.group_id,
                "skill_id": groups_by_id.get(report.group_id).skill_id
                if groups_by_id.get(report.group_id) is not None
                else "",
                "skill_name": skill_name(groups_by_id.get(report.group_id).skill_id)
                if groups_by_id.get(report.group_id) is not None
                else "",
                "status": report.status,
                "content_text": report.content_text,
            }
            for report in day_reports
        ]
        days.append(
            {
                "id": representative.id,
                "group_id": representative.group_id,
                "user_id": representative.user_id,
                "date": report_date.isoformat(),
                "status": "ready" if personal_ready else representative.status,
                "completed": team_complete,
                "reported": personal_ready,
                "prime_awarded": team_complete and personal_ready,
                "content_text": representative.content_text,
                "support_given": representative.support_given,
                "attachments": [],
                "reports": report_items,
            }
        )

    tracking_start = (
        first_membership_at.date() if first_membership_at is not None else None
    )
    metrics = streak_snapshot(
        completed_team_dates,
        tracking_start=tracking_start,
        successful_days=user.successful_days,
        prime_points=user.prime_points,
        shield_pending=user.shield_pending,
        neutral=pending_team_dates,
    )
    if metrics.get("shield_gap_used") and user.shield_pending:
        user.shield_pending = False
        session.add(user)
        await session.commit()

    return {
        "days": days,
        "has_more": has_more,
        "today": date.today().isoformat(),
        "tracking_start_date": tracking_start.isoformat() if tracking_start else None,
        "current_streak": metrics["current_streak"],
        "best_streak": metrics["best_streak"],
        "successful_days": user.successful_days,
        "prime_points": user.prime_points,
        "cycle_pace_percent": metrics["cycle_pace_percent"],
        "insights": metrics["insights"],
        "streak_shields": user.streak_shields,
        "shield_pending": user.shield_pending,
    }


@router.post("/reports")
async def create_report(
    payload: dict,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    group_id = str(payload.get("group_id") or "")
    group = await _require_active_group(session, group_id, user)
    content_text = str(payload.get("content_text") or "").strip()
    report_status = str(payload.get("status") or "ready")
    if report_status not in {"ready", "not_ready"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный статус отчёта")
    attachments_data = payload.get("attachments") or []
    if not isinstance(attachments_data, list):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный список вложений")
    if report_status == "ready" and not content_text and not attachments_data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Добавьте текст, фото или видео")

    from ..timezone_utils import group_today

    today = group_today(group)
    report = await session.scalar(
        select(HabitReport).where(
            HabitReport.group_id == group.id,
            HabitReport.user_id == user.id,
            HabitReport.report_date == today,
        )
    )
    previous_status = report.status if report is not None else None
    if report is None:
        report = HabitReport(group_id=group.id, user_id=user.id, report_date=today)
    report.content_text = content_text
    report.status = report_status
    report.support_given = bool(payload.get("support_given") or False)
    session.add(report)
    await session.flush()
    await session.execute(delete(ReportAttachment).where(ReportAttachment.report_id == report.id))
    allowed_attachment_types = {"image", "video", "video_note", "audio"}
    chat_attachments: list[dict] = []
    for item in attachments_data:
        if not isinstance(item, dict):
            continue
        media_type = str(item.get("media_type") or "")
        storage_url = str(item.get("storage_url") or item.get("mxc_url") or "")
        is_existing_attachment = bool(item.get("existing") or item.get("id"))
        if media_type not in allowed_attachment_types or not storage_url:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверное вложение отчёта")
        session.add(
            ReportAttachment(
                report_id=report.id,
                media_type=media_type,
                url=storage_url,
                filename=str(item.get("filename") or ""),
                content_type=str(item.get("content_type") or "application/octet-stream"),
                size_bytes=int(item.get("size_bytes") or 0),
                duration_ms=int(item["duration_ms"]) if item.get("duration_ms") is not None else None,
                thumbnail_url=str(item.get("thumbnail_url") or "") or None,
            )
        )
        if not is_existing_attachment:
            chat_attachments.append(
                {
                    "media_type": media_type,
                    "url": storage_url,
                    "filename": str(item.get("filename") or ""),
                    "content_type": str(item.get("content_type") or "application/octet-stream"),
                    "size_bytes": int(item.get("size_bytes") or 0),
                    "duration_ms": int(item["duration_ms"]) if item.get("duration_ms") is not None else None,
                    "thumbnail_url": str(item.get("thumbnail_url") or "") or None,
                }
            )
    if report_status == "ready":
        if content_text:
            try:
                await moderate_text_before_publish(
                    session,
                    user=user,
                    text=content_text,
                    content_type="habit_report",
                )
            except ModerationError as exc:
                raise moderation_http_error(exc) from exc
        for item in attachments_data:
            if not isinstance(item, dict):
                continue
            storage_url = str(item.get("storage_url") or item.get("mxc_url") or "")
            if storage_url and not bool(item.get("existing") or item.get("id")):
                thumb = str(item.get("thumbnail_url") or "") or None
                await validate_media_url_for_scope(
                    session,
                    owner=user,
                    media_url=storage_url,
                    scope_type="report",
                    scope_id=group.id,
                )
                if thumb:
                    await validate_media_url_for_scope(
                        session,
                        owner=user,
                        media_url=thumb,
                        scope_type="report",
                        scope_id=group.id,
                    )

    async def publish_report_to_chat(prefix: str) -> None:
        report_body = prefix
        if content_text:
            report_body = f"{report_body}\n{content_text}"
        elif chat_attachments:
            report_body = f"{report_body}\nВложений: {len(chat_attachments)}"
        await _create_group_chat_message(session, group, user, body=report_body, msgtype="prime.report")

        type_to_msgtype = {
            "image": "m.image",
            "video": "m.video",
            "video_note": "prime.video_note",
            "audio": "m.audio",
        }
        type_to_body = {
            "image": "Фото отчёта",
            "video": "Видео отчёта",
            "video_note": "Видеокружок отчёта",
            "audio": "Аудио отчёта",
        }
        for item in chat_attachments:
            media_type = item["media_type"]
            await _create_group_chat_message(
                session,
                group,
                user,
                body=item["filename"] or type_to_body.get(media_type, "Вложение отчёта"),
                msgtype=type_to_msgtype.get(media_type, "m.file"),
                url=item["url"],
                filename=item["filename"] or None,
                content_type=item["content_type"],
                size_bytes=item["size_bytes"],
                duration_ms=item["duration_ms"],
                thumbnail_url=item["thumbnail_url"],
            )

    prime_awarded = False
    from ..team_day import (
        TEAM_DAY_COMPLETE_MSG,
        TEAM_DAY_PENDING_PREFIX,
        award_team_day_primes,
        recompute_group_day,
        team_day_payload,
    )

    if report_status == "ready" and previous_status != "ready":
        await publish_report_to_chat(TEAM_DAY_PENDING_PREFIX)
    elif report_status == "ready" and previous_status == "ready":
        await publish_report_to_chat("✏️ Отчёт обновлён")

    group_day, just_completed = await recompute_group_day(session, group, today)
    if just_completed:
        awarded_ids = await award_team_day_primes(session, group, today)
        prime_awarded = user.id in awarded_ids
        await _create_group_chat_message(
            session,
            group,
            user,
            body=TEAM_DAY_COMPLETE_MSG,
            msgtype="prime.system",
        )
        # Recalc progress for every active member who got a prime.
        member_rows = (
            await session.execute(
                select(GroupMember, User)
                .join(User, User.id == GroupMember.user_id)
                .where(
                    GroupMember.group_id == group.id,
                    GroupMember.active.is_(True),
                )
            )
        ).all()
        for membership, member_user in member_rows:
            await _sync_user_daily_progress(session, member_user)
            await sync_group_member_streak(
                session,
                membership,
                group_id=group.id,
                user_id=member_user.id,
                today=today,
            )
            await create_notification(
                session,
                member_user.id,
                "team_day_complete",
                "День закрыт вместе",
                "+1 Прайм каждому — команда собрала все отчёты",
                {
                    "group_id": group.id,
                    "date": today.isoformat(),
                    "deep_link": f"prime://groups/{group.id}",
                },
            )
        from .group_service import maybe_transition_cycle_to_voting

        if await maybe_transition_cycle_to_voting(session, group):
            for _, member_user in member_rows:
                await create_notification(
                    session,
                    member_user.id,
                    "group_phase",
                    "Первый цикл завершён",
                    "Выберите, как продолжить с командой",
                    {
                        "group_id": group.id,
                        "phase": "voting",
                        "deep_link": f"prime://groups/{group.id}",
                    },
                )
    else:
        await _sync_user_daily_progress(session, user)
        membership = await _user_membership(session, group.id, user.id)
        await sync_group_member_streak(
            session,
            membership,
            group_id=group.id,
            user_id=user.id,
            today=today,
        )

    _bump_group_revision(group)
    session.add(group)
    await session.commit()
    await session.refresh(report)
    await session.refresh(user)
    result = await _report_payload(session, report)
    result["prime_awarded"] = prime_awarded
    result["successful_days"] = user.successful_days
    result["prime_points"] = user.prime_points
    result["team_day"] = await team_day_payload(session, group, day=today)
    result["group_revision"] = int(group.revision or 0)
    if report_status == "ready":
        preview = (content_text or "").strip()
        if not preview and chat_attachments:
            preview = f"Вложений: {len(chat_attachments)}"
        body_text = f"@{user.nickname} отправил отчёт"
        if preview:
            snippet = preview if len(preview) <= 80 else f"{preview[:77]}…"
            body_text = f"{body_text}: {snippet}"
        await push_group_members(
            session,
            group_id=group.id,
            type="team_report",
            title=skill_name(group.skill_id) or group.name,
            body=body_text,
            exclude_user_id=user.id,
        )
    await _notify_group_members(
        session,
        group_id=group.id,
        reason="report_updated" if not just_completed else "team_day_complete",
    )
    if just_completed:
        active_ids = [row.user_id for row, _ in member_rows]
        await notify_unlocked_milestones(
            session,
            group,
            active_ids,
            milestone_ids={"first_full_day"},
        )
    return result
