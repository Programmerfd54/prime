"""Shared helpers extracted from routers/misc.py."""
from datetime import date, datetime, timedelta, timezone
import asyncio
import mimetypes
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..notifications import create_notification
from ..matrix import (
    create_room,
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
    DirectMessageReaction,
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
from ..group_progress import compute_team_milestones, compute_team_recap, first_ready_report_date
from ..metrics_engine import streak_snapshot, sync_group_member_streak
from ..nicknames import normalize_nickname
from ..regions import is_valid_region, region_name
from ..schemas import parse_privacy_settings
from ..skills_catalog import SKILLS, skill_name

WAITING_ROOM_SIZE = 6
REGION_EXPANSION_DELAY = timedelta(
    minutes=get_settings().group_region_expansion_minutes,
)
PARTIAL_GROUP_START_DELAY = timedelta(
    hours=get_settings().group_partial_start_hours,
)
MIN_GROUP_MEMBERS = get_settings().group_min_members
MAX_MEDIA_BYTES = 100 * 1024 * 1024
MAX_DIRECT_IMAGE_BYTES = 10 * 1024 * 1024
MAX_DIRECT_FILE_BYTES = 25 * 1024 * 1024
# Group chat images/documents are capped to the same limits as direct chat.
# Video/audio keep the higher MAX_MEDIA_BYTES ceiling.
MAX_GROUP_IMAGE_BYTES = MAX_DIRECT_IMAGE_BYTES
MAX_GROUP_FILE_BYTES = MAX_DIRECT_FILE_BYTES
ALLOWED_MEDIA_PREFIXES = ("image/", "video/", "audio/")
ALLOWED_DIRECT_DOCUMENT_TYPES = {
    "application/pdf",
    "text/plain",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/zip",
}
# Group chat document allowlist now matches direct chat (previously pdf/txt only).
ALLOWED_DOCUMENT_TYPES = set(ALLOWED_DIRECT_DOCUMENT_TYPES)
ALLOWED_REACTION_EMOJIS = ("🔥", "💪", "✅", "❤️", "👏", "⚡")
SUPPORT_REACTION_EMOJIS = ("💪", "✅")
CHAT_SUPPORT_REASON = "Поддержка в чате"
ONLINE_PRESENCE_WINDOW = timedelta(minutes=3)
MAX_WAITING_ROOM_SLOTS = 6
MAX_WAITING_ROOM_EVENTS = 5


def _region_color_seed(region_code: str | None) -> int:
    if not region_code:
        return 0
    return sum(ord(char) for char in region_code) % 360


def _pool_filters(entry: WaitingRoomEntry) -> list:
    filters = [WaitingRoomEntry.skill_id == entry.skill_id]
    if not entry.allow_other_regions:
        filters.append(WaitingRoomEntry.region_code == entry.region_code)
    else:
        filters.append(WaitingRoomEntry.allow_other_regions.is_(True))
    return filters


def _ago_seconds(value: datetime, now: datetime) -> int:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return max(0, int((now - value).total_seconds()))


async def _median_match_hours(session: AsyncSession, skill_id: str) -> float | None:
    created_times = (
        await session.execute(
            select(Group.created_at)
            .where(Group.skill_id == skill_id)
            .order_by(Group.created_at.desc())
            .limit(30)
        )
    ).scalars().all()
    if len(created_times) < 2:
        return None
    ordered = sorted(
        item.replace(tzinfo=timezone.utc) if item.tzinfo is None else item
        for item in created_times
    )
    diffs_hours = [
        (ordered[index + 1] - ordered[index]).total_seconds() / 3600
        for index in range(len(ordered) - 1)
    ]
    if not diffs_hours:
        return None
    diffs_hours.sort()
    midpoint = len(diffs_hours) // 2
    if len(diffs_hours) % 2:
        median = diffs_hours[midpoint]
    else:
        median = (diffs_hours[midpoint - 1] + diffs_hours[midpoint]) / 2
    return round(median, 1)


async def _waiting_room_live_fields(
    session: AsyncSession,
    entry: WaitingRoomEntry,
    *,
    current_user_id: str | None = None,
) -> dict:
    now = datetime.now(timezone.utc)
    pool_filters = _pool_filters(entry)
    online_cutoff = now - ONLINE_PRESENCE_WINDOW

    region_searching = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .where(WaitingRoomEntry.region_code == entry.region_code)
        )
        or 0
    )
    skill_searching = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .where(WaitingRoomEntry.skill_id == entry.skill_id)
        )
        or 0
    )
    online_in_pool = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .join(User, User.id == WaitingRoomEntry.user_id)
            .where(
                *pool_filters,
                User.last_seen_at.is_not(None),
                User.last_seen_at >= online_cutoff,
            )
        )
        or 0
    )

    pool_rows = (
        await session.execute(
            select(WaitingRoomEntry, User)
            .join(User, User.id == WaitingRoomEntry.user_id)
            .where(*pool_filters)
            .order_by(WaitingRoomEntry.created_at.asc())
            .limit(MAX_WAITING_ROOM_SLOTS)
        )
    ).all()

    slots: list[dict] = []
    events: list[dict] = []
    for pool_entry, pool_user in pool_rows:
        joined_ago_seconds = _ago_seconds(pool_entry.created_at, now)
        letter_source = (pool_user.nickname or pool_user.name or "?").strip()
        letter = letter_source[:1].upper() if letter_source else "?"
        slots.append(
            {
                "letter": letter,
                "region_code": pool_entry.region_code,
                "region_color_seed": _region_color_seed(pool_entry.region_code),
                "joined_ago_seconds": joined_ago_seconds,
            }
        )
        if current_user_id and pool_entry.user_id != current_user_id:
            events.append(
                {
                    "type": "joined",
                    "text": f"Участник {letter} присоединился",
                    "ago_seconds": joined_ago_seconds,
                }
            )

    events.sort(key=lambda item: item["ago_seconds"])
    events = events[:MAX_WAITING_ROOM_EVENTS]

    median_match_hours = await _median_match_hours(session, entry.skill_id)

    return {
        "online_in_pool": online_in_pool,
        "region_searching": region_searching,
        "skill_searching": skill_searching,
        "slots": slots,
        "events": events,
        "median_match_hours": median_match_hours,
    }


async def waiting_room_stats_payload(
    session: AsyncSession,
    *,
    skill_id: str,
    region_code: str,
) -> dict:
    now = datetime.now(timezone.utc)
    online_cutoff = now - ONLINE_PRESENCE_WINDOW

    region_searching = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .where(WaitingRoomEntry.region_code == region_code)
        )
        or 0
    )
    skill_searching = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .where(WaitingRoomEntry.skill_id == skill_id)
        )
        or 0
    )
    online_in_pool = int(
        await session.scalar(
            select(func.count())
            .select_from(WaitingRoomEntry)
            .join(User, User.id == WaitingRoomEntry.user_id)
            .where(
                WaitingRoomEntry.skill_id == skill_id,
                WaitingRoomEntry.region_code == region_code,
                User.last_seen_at.is_not(None),
                User.last_seen_at >= online_cutoff,
            )
        )
        or 0
    )

    region_counts = (
        await session.execute(
            select(
                WaitingRoomEntry.region_code,
                func.count().label("count"),
            )
            .where(WaitingRoomEntry.skill_id == skill_id)
            .group_by(WaitingRoomEntry.region_code)
            .order_by(func.count().desc(), WaitingRoomEntry.region_code.asc())
            .limit(6)
        )
    ).all()
    top_regions = [
        {
            "code": row.region_code,
            "name": region_name(row.region_code) or row.region_code,
            "count": int(row.count),
        }
        for row in region_counts
    ]

    return {
        "region_code": region_code,
        "region_name": region_name(region_code),
        "skill_id": skill_id,
        "skill_searching": skill_searching,
        "region_searching": region_searching,
        "online_in_pool": online_in_pool,
        "top_regions": top_regions,
        "median_match_hours": await _median_match_hours(session, skill_id),
    }


def _empty_waiting_room_live_fields() -> dict:
    return {
        "online_in_pool": 0,
        "region_searching": 0,
        "skill_searching": 0,
        "slots": [],
        "events": [],
        "median_match_hours": None,
    }

def _user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "nickname": user.nickname,
        "name": user.name,
        "about": user.about,
        "photo_url": user.photo_url,
        "city": user.city,
        "region_code": user.region_code,
        "region_name": region_name(user.region_code),
        "age": user.age,
        "prime_points": user.prime_points,
        "successful_days": user.successful_days,
    }


def _public_user_payload(user: User) -> dict:
    privacy = parse_privacy_settings(user.privacy_settings)
    payload = _user_payload(user)
    if not privacy.get("show_bio", True):
        payload["about"] = ""
    if not privacy.get("show_age", True):
        payload["age"] = None
    if not privacy.get("show_region", True):
        payload["city"] = None
        payload["region_code"] = None
        payload["region_name"] = None
    if not privacy.get("show_streak", True):
        payload["successful_days"] = 0
    if not privacy.get("show_achievements", True):
        payload["prime_points"] = 0
    payload["privacy_settings"] = privacy
    return payload


def _group_intro_body(user: User) -> str:
    lines = [
        "👋 Знакомство",
        f"{user.name or 'Участник'} (@{user.nickname})" if user.nickname else user.name or "Участник",
    ]
    details = []
    user_region_name = region_name(user.region_code)
    if user_region_name:
        details.append(f"Область: {user_region_name}")
    if user.age is not None:
        details.append(f"Возраст: {user.age}")
    if details:
        lines.append(" · ".join(details))
    if user.about:
        lines.extend(["", user.about])
    return "\n".join(lines).strip()


def _team_pulse(
    members: list[dict],
    check_ins: list[dict],
    *,
    team_day: dict | None = None,
) -> dict:
    active = [m for m in members if m.get("active")]
    total = len(active)
    completed = sum(1 for m in active if m.get("report_status") == "ready")
    day_status = (team_day or {}).get("status") or (
        "complete" if total > 0 and completed >= total else "pending"
    )
    waiting_for = (team_day or {}).get("waiting_for") or [
        {
            "user_id": m["user_id"],
            "name": (m.get("profile") or {}).get("name")
            or (m.get("profile") or {}).get("nickname")
            or "Участник",
            "nickname": (m.get("profile") or {}).get("nickname") or "",
        }
        for m in active
        if m.get("report_status") != "ready"
    ]
    if total == 0:
        status_label = "calm"
        message = "Команда формируется"
    elif day_status == "complete" or completed >= total:
        status_label = "all_done"
        message = "День закрыт всей командой"
    elif completed >= max(1, total // 2):
        status_label = "high"
        remaining = total - completed
        message = f"Осталось {remaining} отчёт{'ов' if remaining > 1 else ''} до закрытия дня"
    elif completed == 0:
        status_label = "support"
        message = "Пока никто не отметился — день закрывается вместе"
    else:
        status_label = "calm"
        remaining = total - completed
        message = f"{completed} из {total} · ждём ещё {remaining}"
    return {
        "completed_today": completed,
        "total_active": total,
        "status": status_label,
        "message": message,
        "check_ins_today": check_ins,
        "day_status": day_status,
        "waiting_for": waiting_for,
        "closed_at": (team_day or {}).get("closed_at"),
    }


async def _group_payload(session: AsyncSession, group: Group) -> dict:
    rows = await session.execute(
        select(GroupMember, User)
        .join(User, User.id == GroupMember.user_id)
        .where(GroupMember.group_id == group.id)
        .order_by(GroupMember.created_at.asc())
    )
    today_reports = (
        await session.execute(
            select(HabitReport).where(
                HabitReport.group_id == group.id,
                HabitReport.report_date == date.today(),
            )
        )
    ).scalars().all()
    report_status_by_user = {report.user_id: report.status for report in today_reports}
    members = []
    for member, member_user in rows.all():
        members.append(
            {
                "id": member.id,
                "user_id": member.user_id,
                "role": member.role,
                "confirmed_participation": member.confirmed_participation,
                "accepted_rules": member.accepted_rules,
                "active": member.active,
                "streak": member.streak,
                "best_streak": member.best_streak,
                "report_status": report_status_by_user.get(member.user_id, "not_ready"),
                "profile": _public_user_payload(member_user),
            }
        )

    check_in_rows = (
        await session.execute(
            select(GroupCheckIn, User)
            .join(User, User.id == GroupCheckIn.user_id)
            .where(
                GroupCheckIn.group_id == group.id,
                GroupCheckIn.check_in_date == date.today(),
            )
            .order_by(GroupCheckIn.created_at.desc())
        )
    ).all()
    check_ins = [
        {
            "user_id": check_in.user_id,
            "name": check_in_user.name,
            "nickname": check_in_user.nickname,
            "kind": check_in.kind,
            "created_at": check_in.created_at.isoformat(),
        }
        for check_in, check_in_user in check_in_rows
    ]

    active_member_ids = [m["user_id"] for m in members if m.get("active")]
    cycle_start = await first_ready_report_date(session, group.id)
    team_recap: dict | None = None
    team_milestones: dict | None = None
    if group.status in {"active", "rotating", "voting", "completed"}:
        team_recap = await compute_team_recap(session, group.id, active_member_ids)
        team_milestones = await compute_team_milestones(
            session, group.id, active_member_ids
        )

    from ..team_day import finalize_stale_group_days, team_day_payload

    await finalize_stale_group_days(session, group.id)
    team_day = await team_day_payload(session, group, members=members)

    return {
        "id": group.id,
        "name": group.name,
        "skill_id": group.skill_id,
        "skill_name": skill_name(group.skill_id),
        "status": group.status,
        "is_private": True,
        "invite_code": None,
        "city": None,
        "region_code": group.region_code,
        "region_name": region_name(group.region_code),
        "is_cross_region": group.is_cross_region,
        "max_members": group.max_members,
        "matrix_room_id": group.matrix_room_id,
        "cycle_start_at": cycle_start.isoformat() if cycle_start else None,
        "members_count": len(members),
        "members": members,
        "team_pulse": _team_pulse(members, check_ins, team_day=team_day),
        "team_day": team_day,
        "team_recap": team_recap,
        "team_milestones": team_milestones,
    }


async def _current_group_for_user(session: AsyncSession, user_id: str) -> Group | None:
    result = await session.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(GroupMember.user_id == user_id, GroupMember.active.is_(True))
        .order_by(Group.created_at.desc())
    )
    return result.scalars().first()


async def _group_for_user_skill(
    session: AsyncSession,
    user_id: str,
    skill_id: str,
) -> Group | None:
    result = await session.execute(
        select(Group)
        .join(GroupMember, GroupMember.group_id == Group.id)
        .where(
            GroupMember.user_id == user_id,
            GroupMember.active.is_(True),
            Group.skill_id == skill_id,
            Group.status.in_(("introduction", "rules_pending", "active")),
        )
        .order_by(Group.created_at.desc())
    )
    return result.scalars().first()


async def _user_membership(
    session: AsyncSession,
    group_id: str,
    user_id: str,
) -> GroupMember:
    membership = await session.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
            GroupMember.active.is_(True),
        )
    )
    if membership is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    return membership


async def _create_group(
    session: AsyncSession,
    skill_id: str,
    users: list[User],
    *,
    region_code: str | None,
    is_cross_region: bool,
) -> Group:
    if not MIN_GROUP_MEMBERS <= len(users) <= WAITING_ROOM_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для команды нужно 6 участников",
        )

    group = Group(
        name=skill_name(skill_id) or "Команда PRIME",
        skill_id=skill_id,
        region_code=region_code,
        is_cross_region=is_cross_region,
        status="introduction",
        max_members=len(users),
    )
    session.add(group)
    await session.flush()

    for index, member_user in enumerate(users):
        session.add(
            GroupMember(
                group_id=group.id,
                user_id=member_user.id,
                role="creator" if index == 0 else "member",
            )
        )

    await session.flush()

    skill_label = skill_name(skill_id) or "Команда PRIME"
    for member_user in users:
        await create_notification(
            session,
            member_user.id,
            "match",
            "Команда готова",
            f"Вы собраны в команду «{skill_label}»",
            {"group_id": group.id, "skill_id": skill_id},
        )

    return group


async def _activate_if_ready(session: AsyncSession, group: Group) -> None:
    members = (
        await session.execute(
            select(GroupMember).where(
                GroupMember.group_id == group.id,
                GroupMember.active.is_(True),
            )
        )
    ).scalars().all()
    if len(members) < group.max_members:
        return

    if group.status == "introduction" and all(m.confirmed_participation for m in members):
        group.status = "rules_pending"
        session.add(group)
        await session.flush()

    if group.status == "rules_pending" and all(m.accepted_rules for m in members):
        users = (
            await session.execute(
                select(User)
                .join(GroupMember, GroupMember.user_id == User.id)
                .where(GroupMember.group_id == group.id, GroupMember.active.is_(True))
                .order_by(
                    case((GroupMember.role == "creator", 0), else_=1),
                    GroupMember.created_at.asc(),
                )
            )
        ).scalars().all()
        users_with_matrix = [
            member_user
            for member_user in users
            if member_user.matrix_user_id and member_user.matrix_access_token
        ]
        if not group.matrix_room_id and len(users_with_matrix) == len(users) and users:
            try:
                group.matrix_room_id = await asyncio.wait_for(
                    create_room(
                        users[0],
                        users[1:],
                        f"PRIME: {skill_name(group.skill_id) or group.skill_id}",
                    ),
                    timeout=5,
                )
            except Exception:
                group.matrix_room_id = None
        group.status = "active"
        session.add(group)
        await session.flush()
        for member_user in users:
            await _create_group_chat_message(
                session,
                group,
                member_user,
                body=_group_intro_body(member_user),
            )


async def _fill_group_vacancies(session: AsyncSession, group: Group) -> None:
    """Fill introduction-stage vacancies without returning former members."""
    memberships = (
        await session.execute(
            select(GroupMember).where(GroupMember.group_id == group.id)
        )
    ).scalars().all()
    active_count = sum(1 for item in memberships if item.active)
    excluded_user_ids = {item.user_id for item in memberships}

    while active_count < group.max_members:
        filters = [
            WaitingRoomEntry.skill_id == group.skill_id,
            WaitingRoomEntry.user_id.not_in(excluded_user_ids),
        ]
        if group.is_cross_region:
            filters.append(WaitingRoomEntry.allow_other_regions.is_(True))
        elif group.region_code:
            filters.append(WaitingRoomEntry.region_code == group.region_code)
        candidate = await session.scalar(
            select(WaitingRoomEntry)
            .where(*filters)
            .order_by(WaitingRoomEntry.created_at.asc())
            .with_for_update(skip_locked=True)
            .limit(1)
        )
        if candidate is None:
            break
        if await _group_for_user_skill(session, candidate.user_id, group.skill_id) is not None:
            await session.delete(candidate)
            continue
        session.add(
            GroupMember(
                group_id=group.id,
                user_id=candidate.user_id,
                role="member",
            )
        )
        await session.delete(candidate)
        excluded_user_ids.add(candidate.user_id)
        active_count += 1

    if active_count < group.max_members:
        group.status = "introduction"
        session.add(group)
    await session.flush()

async def _maybe_match_waiting_room(
    session: AsyncSession,
    skill_id: str,
    region_code: str,
) -> Group | None:
    def aware(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

    def can_start_partial(entries: list[WaitingRoomEntry]) -> bool:
        if len(entries) < MIN_GROUP_MEMBERS:
            return False
        oldest = aware(entries[0].created_at)
        return datetime.now(timezone.utc) >= oldest + PARTIAL_GROUP_START_DELAY

    async def create_from_entries(
        selected_entries: list[WaitingRoomEntry],
        *,
        group_region_code: str | None,
        is_cross_region: bool,
    ) -> Group | None:
        users = (
            await session.execute(
                select(User).where(User.id.in_([entry.user_id for entry in selected_entries]))
            )
        ).scalars().all()
        users_by_id = {item.id: item for item in users}
        ordered_users = [
            users_by_id[entry.user_id]
            for entry in selected_entries
            if entry.user_id in users_by_id
        ]
        if len(ordered_users) != len(selected_entries):
            return None

        # Recheck membership while rows are locked: the same user may have six
        # groups, but never two groups for the same skill.
        eligible_users: list[User] = []
        eligible_entries: list[WaitingRoomEntry] = []
        for entry, queued_user in zip(selected_entries, ordered_users, strict=False):
            if await _group_for_user_skill(session, queued_user.id, skill_id) is None:
                eligible_entries.append(entry)
                eligible_users.append(queued_user)
        if len(eligible_users) != len(selected_entries):
            return None

        group = await _create_group(
            session,
            skill_id,
            eligible_users,
            region_code=group_region_code,
            is_cross_region=is_cross_region,
        )
        await session.execute(
            delete(WaitingRoomEntry).where(
                WaitingRoomEntry.id.in_([entry.id for entry in eligible_entries])
            )
        )
        await session.flush()
        return group

    local_entries = (
        await session.execute(
            select(WaitingRoomEntry)
            .where(
                WaitingRoomEntry.skill_id == skill_id,
                WaitingRoomEntry.region_code == region_code,
            )
            .order_by(WaitingRoomEntry.created_at.asc())
            .with_for_update(skip_locked=True)
        )
    ).scalars().all()

    def prefer_pairs(entries: list[WaitingRoomEntry], limit: int) -> list[WaitingRoomEntry]:
        """Keep pair_code-linked entries together when filling a team."""
        if not entries or limit <= 0:
            return []
        selected: list[WaitingRoomEntry] = []
        selected_ids: set[str] = set()
        by_code: dict[str, list[WaitingRoomEntry]] = {}
        for entry in entries:
            if entry.pair_code:
                by_code.setdefault(entry.pair_code, []).append(entry)

        for entry in entries:
            if entry.id in selected_ids:
                continue
            if len(selected) >= limit:
                break
            if entry.pair_code and entry.pair_code in by_code:
                partners = by_code[entry.pair_code]
                room = limit - len(selected)
                for partner in partners[:room]:
                    if partner.id in selected_ids:
                        continue
                    selected.append(partner)
                    selected_ids.add(partner.id)
            else:
                selected.append(entry)
                selected_ids.add(entry.id)
        return selected

    if len(local_entries) >= WAITING_ROOM_SIZE:
        return await create_from_entries(
            prefer_pairs(local_entries, WAITING_ROOM_SIZE),
            group_region_code=region_code,
            is_cross_region=False,
        )

    cross_region_entries = (
        await session.execute(
            select(WaitingRoomEntry)
            .where(
                WaitingRoomEntry.skill_id == skill_id,
                WaitingRoomEntry.allow_other_regions.is_(True),
            )
            .order_by(WaitingRoomEntry.created_at.asc())
            .with_for_update(skip_locked=True)
        )
    ).scalars().all()
    if len(cross_region_entries) >= WAITING_ROOM_SIZE:
        selected_entries = prefer_pairs(cross_region_entries, WAITING_ROOM_SIZE)
        region_codes = {entry.region_code for entry in selected_entries}
        return await create_from_entries(
            selected_entries,
            group_region_code=None if len(region_codes) > 1 else next(iter(region_codes)),
            is_cross_region=len(region_codes) > 1,
        )

    if can_start_partial(local_entries):
        return await create_from_entries(
            prefer_pairs(local_entries, WAITING_ROOM_SIZE),
            group_region_code=region_code,
            is_cross_region=False,
        )

    if can_start_partial(cross_region_entries):
        selected_entries = prefer_pairs(cross_region_entries, WAITING_ROOM_SIZE)
        region_codes = {entry.region_code for entry in selected_entries}
        return await create_from_entries(
            selected_entries,
            group_region_code=None if len(region_codes) > 1 else next(iter(region_codes)),
            is_cross_region=len(region_codes) > 1,
        )

    return None


async def waiting_room_payload(
    session: AsyncSession,
    entry: WaitingRoomEntry | None,
    matched_group_id: str | None = None,
    *,
    current_user_id: str | None = None,
) -> dict:
    if entry is None:
        return {
            "in_queue": False,
            "skill_id": None,
            "skill_name": None,
            "people_waiting": 0,
            "needed": WAITING_ROOM_SIZE,
            "min_members": MIN_GROUP_MEMBERS,
            "matched_group_id": matched_group_id,
            "region_code": None,
            "region_name": None,
            "can_expand_search": False,
            "allow_other_regions": False,
            "expansion_available_at": None,
            "partial_start_available_at": None,
            **_empty_waiting_room_live_fields(),
        }

    count_filters = _pool_filters(entry)
    count_result = await session.execute(
        select(func.count()).select_from(WaitingRoomEntry).where(*count_filters)
    )
    people_waiting = int(count_result.scalar_one())
    now = datetime.now(timezone.utc)
    created_at = entry.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    expansion_available_at = created_at + REGION_EXPANSION_DELAY
    partial_start_available_at = created_at + PARTIAL_GROUP_START_DELAY
    can_expand = now >= expansion_available_at and not entry.allow_other_regions
    if can_expand and entry.expansion_offered_at is None:
        entry.expansion_offered_at = now
        session.add(entry)
        await session.flush()
    live_fields = await _waiting_room_live_fields(
        session,
        entry,
        current_user_id=current_user_id,
    )
    return {
        "in_queue": True,
        "skill_id": entry.skill_id,
        "skill_name": skill_name(entry.skill_id),
        "people_waiting": people_waiting,
        "needed": WAITING_ROOM_SIZE,
        "min_members": MIN_GROUP_MEMBERS,
        "matched_group_id": matched_group_id,
        "region_code": entry.region_code,
        "region_name": region_name(entry.region_code),
        "can_expand_search": can_expand,
        "allow_other_regions": entry.allow_other_regions,
        "expansion_available_at": expansion_available_at.isoformat(),
        "partial_start_available_at": partial_start_available_at.isoformat(),
        **live_fields,
    }


def _friendship_pair(left_user_id: str, right_user_id: str) -> tuple[str, str]:
    return tuple(sorted((left_user_id, right_user_id)))  # type: ignore[return-value]


async def _are_friends(session: AsyncSession, left_user_id: str, right_user_id: str) -> bool:
    low, high = _friendship_pair(left_user_id, right_user_id)
    friendship = await session.scalar(
        select(Friendship).where(
            Friendship.user_low_id == low,
            Friendship.user_high_id == high,
        )
    )
    return friendship is not None


def _friend_request_payload(request: FriendRequest, requester: User) -> dict:
    return {
        "id": request.id,
        "status": request.status,
        "created_at": request.created_at.isoformat(),
        "requester": _user_payload(requester),
    }


def _direct_conversation_key(left_user_id: str, right_user_id: str) -> str:
    low, high = _friendship_pair(left_user_id, right_user_id)
    return f"{low}:{high}"


def _direct_message_payload(
    message: DirectMessage,
    *,
    reactions: list[DirectMessageReaction] | None = None,
    current_user_id: str | None = None,
    reply_preview: str | None = None,
    read_by_peer: bool | None = None,
) -> dict:
    payload = {
        "id": message.id,
        "client_id": message.client_id,
        "sender_user_id": message.sender_user_id,
        "recipient_user_id": message.recipient_user_id,
        "reply_to_id": message.reply_to_id,
        "reply_preview": reply_preview,
        "msgtype": message.msgtype or "m.text",
        "body": message.body,
        "url": mxc_to_http(message.url) if message.url else None,
        "filename": message.filename,
        "content_type": message.content_type,
        "size_bytes": message.size_bytes,
        "created_at": message.created_at.isoformat(),
        "timestamp": int(message.created_at.timestamp() * 1000),
        "reactions": _direct_reaction_payloads(
            message.id,
            reactions or [],
            current_user_id or "",
        ),
        "available_reactions": list(ALLOWED_REACTION_EMOJIS),
    }
    if read_by_peer is not None:
        payload["read_by_peer"] = read_by_peer
    return payload


def _direct_reaction_payloads(
    message_id: str,
    reactions: list[DirectMessageReaction],
    current_user_id: str,
) -> list[dict]:
    counts: dict[str, int] = {}
    reacted_by_me: set[str] = set()
    for reaction in reactions:
        if reaction.message_id != message_id:
            continue
        counts[reaction.emoji] = counts.get(reaction.emoji, 0) + 1
        if reaction.user_id == current_user_id:
            reacted_by_me.add(reaction.emoji)
    return [
        {
            "emoji": emoji,
            "count": counts[emoji],
            "reacted_by_me": emoji in reacted_by_me,
        }
        for emoji in ALLOWED_REACTION_EMOJIS
        if counts.get(emoji, 0) > 0
    ]


async def _direct_messages_payloads(
    session: AsyncSession,
    messages: list[DirectMessage],
    current_user_id: str,
    *,
    peer_last_read_at: datetime | None = None,
) -> list[dict]:
    if not messages:
        return []
    message_ids = [message.id for message in messages]
    reply_ids = {message.reply_to_id for message in messages if message.reply_to_id}
    replies_by_id: dict[str, DirectMessage] = {}
    if reply_ids:
        reply_rows = (
            await session.execute(select(DirectMessage).where(DirectMessage.id.in_(reply_ids)))
        ).scalars().all()
        replies_by_id = {item.id: item for item in reply_rows}
    reactions: list[DirectMessageReaction] = []
    if message_ids:
        reactions = (
            await session.execute(
                select(DirectMessageReaction).where(
                    DirectMessageReaction.message_id.in_(message_ids)
                )
            )
        ).scalars().all()
    return [
        _direct_message_payload(
            message,
            reactions=reactions,
            current_user_id=current_user_id,
            reply_preview=_direct_reply_preview(replies_by_id.get(message.reply_to_id))
            if message.reply_to_id
            else None,
            read_by_peer=(
                peer_last_read_at is not None
                and message.sender_user_id == current_user_id
                and message.created_at <= peer_last_read_at
            )
            if peer_last_read_at is not None
            else None,
        )
        for message in messages
    ]


def _direct_reply_preview(message: DirectMessage | None) -> str | None:
    if message is None:
        return None
    msgtype = message.msgtype or "m.text"
    if msgtype == "m.image":
        return "Изображение"
    if msgtype == "m.file":
        return message.filename or "Файл"
    body = (message.body or "").strip()
    if len(body) > 120:
        return f"{body[:117]}..."
    return body or None


def _looks_like_report_chat_message(message: ChatMessage) -> bool:
    if message.msgtype == "prime.report":
        return True
    body = (message.body or "").strip()
    return body.startswith("✅ Отчёт") or body.startswith("✏️ Отчёт")


async def _maybe_award_chat_support(
    session: AsyncSession,
    *,
    message: ChatMessage,
    supporter: User,
    emoji: str,
    group: Group,
) -> bool:
    if emoji not in SUPPORT_REACTION_EMOJIS:
        return False
    if not _looks_like_report_chat_message(message):
        return False
    if message.sender_user_id == supporter.id:
        return False
    today = date.today()
    already = await session.scalar(
        select(PrimeEvent.id).where(
            PrimeEvent.user_id == supporter.id,
            PrimeEvent.reason == CHAT_SUPPORT_REASON,
            func.date(PrimeEvent.created_at) == today,
        )
    )
    if already is not None:
        return False
    author = await session.get(User, message.sender_user_id)
    if author is None:
        return False
    session.add(
        PrimeEvent(
            user_id=author.id,
            amount=1,
            reason=CHAT_SUPPORT_REASON,
            skill_id=group.skill_id,
            group_id=group.id,
        )
    )
    # Do NOT mutate author.prime_points here — _sync_user_daily_progress
    # recomputes from PrimeEvent + team days and would overwrite.
    return True


async def _friend_ids_for_user(session: AsyncSession, user_id: str) -> list[str]:
    friendships = (
        await session.execute(
            select(Friendship).where(
                or_(
                    Friendship.user_low_id == user_id,
                    Friendship.user_high_id == user_id,
                )
            )
        )
    ).scalars().all()
    return [
        item.user_high_id if item.user_low_id == user_id else item.user_low_id
        for item in friendships
    ]


async def _mark_direct_chat_read(
    session: AsyncSession,
    user_id: str,
    friend_id: str,
) -> datetime:
    now = utcnow()
    state = await session.scalar(
        select(DirectConversationRead).where(
            DirectConversationRead.user_id == user_id,
            DirectConversationRead.friend_id == friend_id,
        )
    )
    if state is None:
        state = DirectConversationRead(
            user_id=user_id,
            friend_id=friend_id,
            last_read_at=now,
        )
    else:
        state.last_read_at = now
    session.add(state)
    await session.commit()
    return now


async def _direct_chat_inbox_items(
    session: AsyncSession,
    user: User,
) -> list[dict]:
    friend_ids = await _friend_ids_for_user(session, user.id)
    if not friend_ids:
        return []

    friends = (
        await session.execute(select(User).where(User.id.in_(friend_ids)))
    ).scalars().all()
    friends_by_id = {friend.id: friend for friend in friends}

    read_rows = (
        await session.execute(
            select(DirectConversationRead).where(
                DirectConversationRead.user_id == user.id,
                DirectConversationRead.friend_id.in_(friend_ids),
            )
        )
    ).scalars().all()
    read_by_friend = {row.friend_id: row.last_read_at for row in read_rows}

    items: list[dict] = []
    for friend_id in friend_ids:
        friend = friends_by_id.get(friend_id)
        if friend is None:
            continue
        conversation_key = _direct_conversation_key(user.id, friend_id)
        last_message = await session.scalar(
            select(DirectMessage)
            .where(DirectMessage.conversation_key == conversation_key)
            .order_by(DirectMessage.created_at.desc())
            .limit(1)
        )
        last_read_at = read_by_friend.get(friend_id)
        unread_filters = [
            DirectMessage.conversation_key == conversation_key,
            DirectMessage.recipient_user_id == user.id,
        ]
        if last_read_at is not None:
            unread_filters.append(DirectMessage.created_at > last_read_at)
        unread_count = int(
            await session.scalar(select(func.count()).where(*unread_filters)) or 0
        )
        items.append(
            {
                "friend": _user_payload(friend),
                "last_message": (
                    _direct_message_payload(last_message) if last_message else None
                ),
                "unread_count": unread_count,
            }
        )

    with_messages = [item for item in items if item.get("last_message")]
    without_messages = [item for item in items if not item.get("last_message")]
    with_messages.sort(
        key=lambda item: item["last_message"]["created_at"],
        reverse=True,
    )
    without_messages.sort(
        key=lambda item: (
            item["friend"].get("name") or item["friend"].get("nickname") or ""
        ).lower(),
    )
    return with_messages + without_messages


async def _create_friend_request_for_addressee(
    session: AsyncSession,
    requester: User,
    addressee: User,
) -> dict:
    if addressee.id == requester.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="  ")
    if await _are_friends(session, requester.id, addressee.id):
        return {"status": "accepted"}

    reverse = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.requester_user_id == addressee.id,
            FriendRequest.addressee_user_id == requester.id,
            FriendRequest.status == "pending",
        )
    )
    if reverse is not None:
        low, high = _friendship_pair(requester.id, addressee.id)
        session.add(Friendship(user_low_id=low, user_high_id=high))
        reverse.status = "accepted"
        session.add(reverse)
        await session.commit()
        return {"status": "accepted"}

    existing = await session.scalar(
        select(FriendRequest).where(
            FriendRequest.requester_user_id == requester.id,
            FriendRequest.addressee_user_id == addressee.id,
        )
    )
    if existing is None:
        existing = FriendRequest(requester_user_id=requester.id, addressee_user_id=addressee.id)
    elif existing.status != "pending":
        existing.status = "pending"
    session.add(existing)
    await session.commit()
    await session.refresh(existing)
    return {"status": existing.status, "request_id": existing.id}


async def _require_active_group(
    session: AsyncSession,
    group_id: str,
    user: User,
) -> Group:
    await _user_membership(session, group_id, user.id)
    group = await session.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Группа не найдена")
    if group.status != "active":
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail="Чат откроется после принятия правил всеми участниками",
        )
    return group


def _reaction_payloads(
    message_id: str,
    reactions: list[ChatMessageReaction],
    current_user_id: str,
) -> list[dict]:
    counts: dict[str, int] = {}
    reacted_by_me: set[str] = set()
    for reaction in reactions:
        if reaction.message_id != message_id:
            continue
        counts[reaction.emoji] = counts.get(reaction.emoji, 0) + 1
        if reaction.user_id == current_user_id:
            reacted_by_me.add(reaction.emoji)
    return [
        {
            "emoji": emoji,
            "count": counts[emoji],
            "reacted_by_me": emoji in reacted_by_me,
        }
        for emoji in ALLOWED_REACTION_EMOJIS
        if counts.get(emoji, 0) > 0
    ]


def _chat_message_payload(
    message: ChatMessage,
    sender_user: User | None = None,
    *,
    reactions: list[ChatMessageReaction] | None = None,
    current_user_id: str | None = None,
) -> dict:
    return {
        "id": message.id,
        "event_id": message.event_id,
        "sender_user_id": message.sender_user_id,
        "sender": message.sender_matrix_id,
        "sender_profile": _user_payload(sender_user) if sender_user is not None else None,
        "msgtype": message.msgtype,
        "body": message.body,
        "url": mxc_to_http(message.url),
        "filename": message.filename,
        "content_type": message.content_type,
        "size_bytes": message.size_bytes,
        "duration_ms": message.duration_ms,
        "thumbnail_url": mxc_to_http(message.thumbnail_url),
        "reactions": _reaction_payloads(
            message.id,
            reactions or [],
            current_user_id or "",
        ),
        "available_reactions": list(ALLOWED_REACTION_EMOJIS),
        "timestamp": int(message.created_at.timestamp() * 1000),
    }


async def _chat_payloads(
    session: AsyncSession,
    messages: list[ChatMessage],
    current_user_id: str,
) -> list[dict]:
    sender_ids = {message.sender_user_id for message in messages if message.sender_user_id}
    message_ids = [message.id for message in messages]
    users_by_id: dict[str, User] = {}
    if sender_ids:
        users = (await session.execute(select(User).where(User.id.in_(sender_ids)))).scalars().all()
        users_by_id = {user.id: user for user in users}
    reactions: list[ChatMessageReaction] = []
    if message_ids:
        reactions = (
            await session.execute(
                select(ChatMessageReaction).where(ChatMessageReaction.message_id.in_(message_ids))
            )
        ).scalars().all()
    return [
        _chat_message_payload(
            message,
            users_by_id.get(message.sender_user_id),
            reactions=reactions,
            current_user_id=current_user_id,
        )
        for message in messages
    ]


async def _create_group_chat_message(
    session: AsyncSession,
    group: Group,
    user: User,
    *,
    body: str,
    msgtype: str = "m.text",
    url: str | None = None,
    filename: str | None = None,
    content_type: str | None = None,
    size_bytes: int | None = None,
    duration_ms: int | None = None,
    thumbnail_url: str | None = None,
) -> ChatMessage:
    content = {"msgtype": msgtype, "body": body}
    if url:
        content["url"] = url
    info = {
        key: value
        for key, value in {
            "filename": filename,
            "content_type": content_type,
            "size_bytes": size_bytes,
            "duration_ms": duration_ms,
            "thumbnail_url": thumbnail_url,
        }.items()
        if value not in (None, "")
    }
    if info:
        content["info"] = info
    event_id = await send_room_message(user, group.matrix_room_id, content)
    message = ChatMessage(
        group_id=group.id,
        sender_user_id=user.id,
        sender_matrix_id=user.matrix_user_id or user.id,
        event_id=event_id,
        msgtype=msgtype,
        body=body,
        url=url,
        filename=filename,
        content_type=content_type,
        size_bytes=size_bytes,
        duration_ms=duration_ms,
        thumbnail_url=thumbnail_url,
    )
    session.add(message)
    await session.flush()
    return message


async def _report_payload(session: AsyncSession, report: HabitReport) -> dict:
    from ..models import GroupDay

    attachments = (
        await session.execute(
            select(ReportAttachment)
            .where(ReportAttachment.report_id == report.id)
            .order_by(ReportAttachment.created_at.asc())
        )
    ).scalars().all()
    group_day = await session.scalar(
        select(GroupDay).where(
            GroupDay.group_id == report.group_id,
            GroupDay.day_date == report.report_date,
        )
    )
    team_complete = group_day is not None and group_day.status == "complete"
    personal_ready = report.status == "ready"
    return {
        "id": report.id,
        "group_id": report.group_id,
        "user_id": report.user_id,
        "date": report.report_date.isoformat(),
        "status": report.status,
        "completed": team_complete,
        "reported": personal_ready,
        "prime_awarded": team_complete and personal_ready,
        "content_text": report.content_text,
        "support_given": report.support_given,
        "attachments": [
            {
                "id": item.id,
                "media_type": item.media_type,
                "storage_url": item.url,
                "mxc_url": item.url,
                "url": mxc_to_http(item.url),
                "filename": item.filename,
                "content_type": item.content_type,
                "size_bytes": item.size_bytes,
                "duration_ms": item.duration_ms,
                "thumbnail_url": mxc_to_http(item.thumbnail_url),
            }
            for item in attachments
        ],
    }


async def _sync_user_daily_progress(session: AsyncSession, user: User) -> None:
    from ..team_day import count_successful_team_days, count_team_day_primes

    prime_total = await count_team_day_primes(session, user.id)
    successful_days = await count_successful_team_days(session, user.id)
    user.prime_points = prime_total
    user.successful_days = successful_days
    user.can_create_custom_skills = prime_total >= 10
    session.add(user)


