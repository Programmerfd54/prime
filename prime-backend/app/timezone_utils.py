"""Team reporting day timezone helpers.

Reference timezone for a group is fixed at cycle start (rules_pending → active).
Until then, a provisional timezone is used for prep-phase UI only.
"""

from __future__ import annotations

from collections import Counter
from datetime import date, datetime, time, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import Group, GroupMember, User

DEFAULT_RU_TZ = "Europe/Moscow"
DEFAULT_FALLBACK_TZ = "UTC"


def normalize_timezone(value: str | None) -> str | None:
    if not value or not str(value).strip():
        return None
    candidate = str(value).strip()
    try:
        ZoneInfo(candidate)
    except ZoneInfoNotFoundError:
        return None
    return candidate


def fallback_timezone_for_group(group: Group) -> str:
    """Default when majority cannot be determined."""
    if group.region_code:
        return DEFAULT_RU_TZ
    return DEFAULT_FALLBACK_TZ


def effective_group_timezone(group: Group) -> str:
    stored = normalize_timezone(getattr(group, "reference_timezone", None))
    if stored:
        return stored
    return fallback_timezone_for_group(group)


def group_today(group: Group, *, tz: str | None = None) -> date:
    zone = ZoneInfo(tz or effective_group_timezone(group))
    return datetime.now(zone).date()


def team_day_window(tz_name: str, day: date) -> dict:
    """Inclusive calendar day in reference TZ → UTC bounds."""
    zone = ZoneInfo(tz_name)
    day_start = datetime.combine(day, time.min, tzinfo=zone)
    next_day = day.fromordinal(day.toordinal() + 1)
    day_end = datetime.combine(next_day, time.min, tzinfo=zone)
    closes_at = day_end
    return {
        "day_start": day_start,
        "day_end": day_end,
        "closes_at": closes_at.astimezone(timezone.utc),
    }


async def member_timezones(
    session: AsyncSession,
    group_id: str,
    *,
    active_only: bool = True,
) -> list[str]:
    filters = [GroupMember.group_id == group_id]
    if active_only:
        filters.append(GroupMember.active.is_(True))
    rows = (
        await session.execute(
            select(User.timezone)
            .join(GroupMember, GroupMember.user_id == User.id)
            .where(*filters)
        )
    ).all()
    result: list[str] = []
    for (tz,) in rows:
        normalized = normalize_timezone(tz)
        if normalized:
            result.append(normalized)
    return result


async def resolve_group_timezone(
    session: AsyncSession,
    group: Group,
) -> str:
    """Majority IANA TZ of active members; tie / empty → regional fallback."""
    zones = await member_timezones(session, group.id, active_only=True)
    if not zones:
        return fallback_timezone_for_group(group)
    counts = Counter(zones)
    top_count = max(counts.values())
    leaders = [tz for tz, count in counts.items() if count == top_count]
    if len(leaders) == 1:
        return leaders[0]
    return fallback_timezone_for_group(group)


async def ensure_group_reference_timezone(
    session: AsyncSession,
    group: Group,
) -> str:
    """Fix reference timezone at cycle start; idempotent afterward."""
    existing = normalize_timezone(getattr(group, "reference_timezone", None))
    if existing:
        return existing
    resolved = await resolve_group_timezone(session, group)
    group.reference_timezone = resolved
    session.add(group)
    await session.flush()
    return resolved


def team_day_metadata(group: Group, day: date) -> dict:
    tz_name = effective_group_timezone(group)
    window = team_day_window(tz_name, day)
    return {
        "reference_timezone": tz_name,
        "closes_at": window["closes_at"].isoformat(),
    }
