"""Team-day (all-or-nothing) scoring helpers.

A calendar day for a group is `complete` only when every active member has a
`ready` HabitReport. Primes and successful days are awarded only for complete
team days. Days where the user reported but the team did not finish are
`neutral` — they neither extend nor break the streak.
"""

from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import Group, GroupDay, GroupMember, HabitReport, PrimeEvent, User, utcnow

TEAM_DAY_PRIME_REASON = "Полный день команды"
TEAM_DAY_COMPLETE_MSG = "🎉 День закрыт всей командой — +1 Прайм каждому"
TEAM_DAY_PENDING_PREFIX = "✅ Отчёт принят"


def team_day_prime_reason(day: date) -> str:
    return f"{TEAM_DAY_PRIME_REASON}:{day.isoformat()}"


def is_team_day_prime_reason(reason: str | None) -> bool:
    if not reason:
        return False
    return reason == TEAM_DAY_PRIME_REASON or reason.startswith(
        f"{TEAM_DAY_PRIME_REASON}:"
    )


async def _active_member_ids(session: AsyncSession, group_id: str) -> list[str]:
    rows = (
        await session.execute(
            select(GroupMember.user_id).where(
                GroupMember.group_id == group_id,
                GroupMember.active.is_(True),
            )
        )
    ).all()
    return [row[0] for row in rows]


async def _ready_user_ids(
    session: AsyncSession,
    group_id: str,
    day: date,
) -> set[str]:
    rows = (
        await session.execute(
            select(HabitReport.user_id).where(
                HabitReport.group_id == group_id,
                HabitReport.report_date == day,
                HabitReport.status == "ready",
            )
        )
    ).all()
    return {row[0] for row in rows}


async def get_or_create_group_day(
    session: AsyncSession,
    group_id: str,
    day: date,
) -> GroupDay:
    existing = await session.scalar(
        select(GroupDay).where(
            GroupDay.group_id == group_id,
            GroupDay.day_date == day,
        )
    )
    if existing is not None:
        return existing
    day_row = GroupDay(group_id=group_id, day_date=day, status="pending")
    session.add(day_row)
    await session.flush()
    return day_row


async def recompute_group_day(
    session: AsyncSession,
    group: Group,
    day: date | None = None,
) -> tuple[GroupDay, bool]:
    """Recompute today's GroupDay.

    Returns (group_day, just_completed) where just_completed is True only on
    the transition pending/missed → complete.
    """
    day = day or date.today()
    member_ids = await _active_member_ids(session, group.id)
    ready_ids = await _ready_user_ids(session, group.id, day)
    ready_among_active = ready_ids & set(member_ids)
    member_count = len(member_ids)
    ready_count = len(ready_among_active)

    group_day = await get_or_create_group_day(session, group.id, day)
    previous_status = group_day.status
    group_day.member_count = member_count
    group_day.ready_count = ready_count

    just_completed = False
    if member_count > 0 and ready_count >= member_count:
        if previous_status != "complete":
            just_completed = True
            group_day.completed_at = utcnow()
        group_day.status = "complete"
    elif day < date.today():
        group_day.status = "missed"
        group_day.completed_at = None
    else:
        group_day.status = "pending"
        group_day.completed_at = None

    session.add(group_day)
    await session.flush()
    return group_day, just_completed


async def finalize_stale_group_days(
    session: AsyncSession,
    group_id: str,
    *,
    today: date | None = None,
) -> int:
    """Lazy rollover: mark past pending GroupDays as missed."""
    today = today or date.today()
    rows = (
        await session.execute(
            select(GroupDay).where(
                GroupDay.group_id == group_id,
                GroupDay.status == "pending",
                GroupDay.day_date < today,
            )
        )
    ).scalars().all()
    for row in rows:
        row.status = "missed"
        session.add(row)
    return len(rows)


async def team_day_payload(
    session: AsyncSession,
    group: Group,
    *,
    day: date | None = None,
    members: list[dict] | None = None,
) -> dict:
    day = day or date.today()
    await finalize_stale_group_days(session, group.id, today=day)
    group_day, _ = await recompute_group_day(session, group, day)

    if members is None:
        member_ids = await _active_member_ids(session, group.id)
        ready_ids = await _ready_user_ids(session, group.id, day)
        waiting_for: list[dict] = []
        for uid in member_ids:
            if uid in ready_ids:
                continue
            user = await session.get(User, uid)
            if user is None:
                continue
            waiting_for.append(
                {
                    "user_id": uid,
                    "name": user.name or user.nickname or "Участник",
                    "nickname": user.nickname or "",
                }
            )
    else:
        waiting_for = [
            {
                "user_id": m["user_id"],
                "name": (m.get("profile") or {}).get("name")
                or (m.get("profile") or {}).get("nickname")
                or "Участник",
                "nickname": (m.get("profile") or {}).get("nickname") or "",
            }
            for m in members
            if m.get("active") and m.get("report_status") != "ready"
        ]

    return {
        "date": day.isoformat(),
        "status": group_day.status,
        "ready_count": group_day.ready_count,
        "member_count": group_day.member_count,
        "waiting_for": waiting_for,
        "closed_at": group_day.completed_at.isoformat()
        if group_day.completed_at
        else None,
    }


async def award_team_day_primes(
    session: AsyncSession,
    group: Group,
    day: date,
) -> list[str]:
    """Award +1 Prime to every active member who has a ready report for `day`.

    Idempotent: skips users who already have a team-day prime event for
    this (group, day).
    """
    member_ids = await _active_member_ids(session, group.id)
    ready_ids = await _ready_user_ids(session, group.id, day)
    reason = team_day_prime_reason(day)
    awarded: list[str] = []
    for uid in member_ids:
        if uid not in ready_ids:
            continue
        already = await session.scalar(
            select(PrimeEvent.id).where(
                PrimeEvent.user_id == uid,
                PrimeEvent.group_id == group.id,
                PrimeEvent.reason == reason,
            )
        )
        if already is not None:
            continue
        session.add(
            PrimeEvent(
                user_id=uid,
                amount=1,
                reason=reason,
                skill_id=group.skill_id,
                group_id=group.id,
            )
        )
        awarded.append(uid)
    await session.flush()
    return awarded


async def team_completed_dates(
    session: AsyncSession,
    user_id: str,
    *,
    group_id: str | None = None,
) -> set[date]:
    """Dates where the user reported ready AND the team day is complete."""
    filters = [
        HabitReport.user_id == user_id,
        HabitReport.status == "ready",
        GroupDay.status == "complete",
        GroupDay.group_id == HabitReport.group_id,
        GroupDay.day_date == HabitReport.report_date,
    ]
    if group_id is not None:
        filters.append(HabitReport.group_id == group_id)
    rows = await session.execute(
        select(HabitReport.report_date)
        .join(
            GroupDay,
            (GroupDay.group_id == HabitReport.group_id)
            & (GroupDay.day_date == HabitReport.report_date),
        )
        .where(*filters)
        .distinct()
    )
    return {row[0] for row in rows.all()}


async def team_pending_dates(
    session: AsyncSession,
    user_id: str,
    *,
    group_id: str | None = None,
) -> set[date]:
    """Dates where the user reported ready but the team day is still pending
    (or was missed) — neutral for streak purposes."""
    filters = [
        HabitReport.user_id == user_id,
        HabitReport.status == "ready",
        GroupDay.status.in_(("pending", "missed")),
        GroupDay.group_id == HabitReport.group_id,
        GroupDay.day_date == HabitReport.report_date,
    ]
    if group_id is not None:
        filters.append(HabitReport.group_id == group_id)
    rows = await session.execute(
        select(HabitReport.report_date)
        .join(
            GroupDay,
            (GroupDay.group_id == HabitReport.group_id)
            & (GroupDay.day_date == HabitReport.report_date),
        )
        .where(*filters)
        .distinct()
    )
    return {row[0] for row in rows.all()}


async def count_team_day_primes(session: AsyncSession, user_id: str) -> int:
    """Prime points from complete team days + other PrimeEvent sources
    (chat support, shields, etc.) that are not team-day awards."""
    team_day_count = await session.scalar(
        select(func.count())
        .select_from(HabitReport)
        .join(
            GroupDay,
            (GroupDay.group_id == HabitReport.group_id)
            & (GroupDay.day_date == HabitReport.report_date),
        )
        .where(
            HabitReport.user_id == user_id,
            HabitReport.status == "ready",
            GroupDay.status == "complete",
        )
    )
    # Bonus / penalty primes that are NOT team-day awards.
    events = (
        await session.execute(
            select(PrimeEvent.amount, PrimeEvent.reason).where(
                PrimeEvent.user_id == user_id,
            )
        )
    ).all()
    bonus = 0
    for amount, reason in events:
        if is_team_day_prime_reason(reason):
            continue
        bonus += int(amount or 0)
    return int(team_day_count or 0) + bonus


async def count_successful_team_days(session: AsyncSession, user_id: str) -> int:
    dates = await team_completed_dates(session, user_id)
    return len(dates)


async def backfill_group_days(session: AsyncSession) -> int:
    """Grandfather historical ready reports as complete team days.

    For every (group_id, report_date) that has at least one ready report and
    no GroupDay row yet, insert a `complete` row so existing users keep their
    primes/streaks.
    """
    rows = (
        await session.execute(
            select(
                HabitReport.group_id,
                HabitReport.report_date,
                func.count(HabitReport.id),
            )
            .where(HabitReport.status == "ready")
            .group_by(HabitReport.group_id, HabitReport.report_date)
        )
    ).all()
    inserted = 0
    for group_id, day_date, ready_count in rows:
        existing = await session.scalar(
            select(GroupDay.id).where(
                GroupDay.group_id == group_id,
                GroupDay.day_date == day_date,
            )
        )
        if existing is not None:
            continue
        member_count = await session.scalar(
            select(func.count(GroupMember.id)).where(
                GroupMember.group_id == group_id,
                GroupMember.active.is_(True),
            )
        )
        session.add(
            GroupDay(
                group_id=group_id,
                day_date=day_date,
                status="complete",
                ready_count=int(ready_count or 0),
                member_count=max(int(member_count or 0), int(ready_count or 0)),
                completed_at=datetime.combine(
                    day_date, datetime.min.time(), tzinfo=timezone.utc
                ),
            )
        )
        inserted += 1
    if inserted:
        await session.flush()
    return inserted
