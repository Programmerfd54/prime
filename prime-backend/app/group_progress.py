from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import ChatMessage, ChatMessageReaction, GroupCheckIn, HabitReport

RECAP_DAYS = 7

MILESTONE_SPECS: tuple[dict[str, object], ...] = (
    {
        "id": "first_full_day",
        "title": "Первый полный день",
        "description": "Вся команда отправила отчёт в один день",
        "target": None,
    },
    {
        "id": "week_together",
        "title": "Неделя вместе",
        "description": "7 дней с отчётами команды",
        "target": 7,
    },
    {
        "id": "hundred_actions",
        "title": "100 действий",
        "description": "100 засчитанных отчётов команды",
        "target": 100,
    },
    {
        "id": "thirty_support",
        "title": "30 поддержек",
        "description": "30 сигналов поддержки в чате и check-in",
        "target": 30,
    },
)


def _recap_message(
    *,
    ready_reports: int,
    pace_percent: int,
    best_day: date | None,
    best_day_count: int,
    support_signals: int,
) -> str:
    if ready_reports == 0:
        return "Пока нет засчитанных отчётов за неделю — начните с сегодняшнего дня"
    parts = [f"За неделю команда закрыла {ready_reports} действий"]
    parts.append(f"темп {pace_percent}%")
    if best_day is not None and best_day_count > 0:
        parts.append(
            f"лучший день — {best_day.strftime('%d.%m')} ({best_day_count} участников)"
        )
    if support_signals > 0:
        parts.append(f"поддержка — {support_signals}")
    return ". ".join(parts) + "."


async def _support_signals_count(
    session: AsyncSession,
    group_id: str,
    *,
    since: date | None = None,
    until: date | None = None,
    support_reports: list[HabitReport] | None = None,
) -> int:
    period_start = since
    period_end = until or date.today()
    if support_reports is None:
        filters = [
            HabitReport.group_id == group_id,
            HabitReport.status == "ready",
            HabitReport.support_given.is_(True),
        ]
        if period_start is not None:
            filters.append(HabitReport.report_date >= period_start)
        filters.append(HabitReport.report_date <= period_end)
        support_reports = (
            await session.execute(select(HabitReport).where(*filters))
        ).scalars().all()

    check_in_filters = [
        GroupCheckIn.group_id == group_id,
        GroupCheckIn.kind.in_(("support", "hard")),
    ]
    if period_start is not None:
        check_in_filters.append(GroupCheckIn.check_in_date >= period_start)
    check_in_filters.append(GroupCheckIn.check_in_date <= period_end)
    check_ins = (
        await session.execute(select(func.count(GroupCheckIn.id)).where(*check_in_filters))
    ).scalar_one()

    reaction_filters = [ChatMessage.group_id == group_id]
    if period_start is not None:
        reaction_filters.append(
            ChatMessageReaction.created_at
            >= datetime.combine(period_start, datetime.min.time(), tzinfo=timezone.utc)
        )
    reaction_filters.append(
        ChatMessageReaction.created_at
        <= datetime.combine(period_end, datetime.max.time(), tzinfo=timezone.utc)
    )
    reactions = (
        await session.execute(
            select(func.count(ChatMessageReaction.id))
            .join(ChatMessage, ChatMessage.id == ChatMessageReaction.message_id)
            .where(*reaction_filters)
        )
    ).scalar_one()

    return len(support_reports) + int(check_ins or 0) + int(reactions or 0)


async def compute_team_recap(
    session: AsyncSession,
    group_id: str,
    active_member_ids: list[str],
) -> dict:
    today = date.today()
    period_start = today - timedelta(days=RECAP_DAYS - 1)
    if not active_member_ids:
        return {
            "period_start": period_start.isoformat(),
            "period_end": today.isoformat(),
            "ready_reports": 0,
            "pace_percent": 0,
            "best_day": None,
            "best_day_count": 0,
            "support_signals": 0,
            "message": "Команда ещё формируется",
        }

    ready_reports = (
        await session.execute(
            select(HabitReport).where(
                HabitReport.group_id == group_id,
                HabitReport.report_date >= period_start,
                HabitReport.report_date <= today,
                HabitReport.status == "ready",
                HabitReport.user_id.in_(active_member_ids),
            )
        )
    ).scalars().all()

    ready_count = len(ready_reports)
    by_date: dict[date, set[str]] = {}
    for report in ready_reports:
        by_date.setdefault(report.report_date, set()).add(report.user_id)

    best_day: date | None = None
    best_day_count = 0
    for report_date, user_ids in by_date.items():
        count = len(user_ids)
        if count > best_day_count:
            best_day = report_date
            best_day_count = count

    possible_slots = len(active_member_ids) * RECAP_DAYS
    pace_percent = round(ready_count / possible_slots * 100) if possible_slots else 0
    pace_percent = min(max(pace_percent, 0), 100)

    support_signals = await _support_signals_count(
        session,
        group_id,
        since=period_start,
        until=today,
        support_reports=[report for report in ready_reports if report.support_given],
    )

    return {
        "period_start": period_start.isoformat(),
        "period_end": today.isoformat(),
        "ready_reports": ready_count,
        "pace_percent": pace_percent,
        "best_day": best_day.isoformat() if best_day else None,
        "best_day_count": best_day_count,
        "support_signals": support_signals,
        "message": _recap_message(
            ready_reports=ready_count,
            pace_percent=pace_percent,
            best_day=best_day,
            best_day_count=best_day_count,
            support_signals=support_signals,
        ),
    }


async def compute_team_milestones(
    session: AsyncSession,
    group_id: str,
    active_member_ids: list[str],
) -> dict:
    active_count = len(active_member_ids)
    if active_count == 0:
        return {"items": []}

    all_ready = (
        await session.execute(
            select(HabitReport).where(
                HabitReport.group_id == group_id,
                HabitReport.status == "ready",
                HabitReport.user_id.in_(active_member_ids),
            )
        )
    ).scalars().all()

    total_ready = len(all_ready)
    users_by_date: dict[date, set[str]] = {}
    active_days: set[date] = set()
    first_full_day: date | None = None
    for report in all_ready:
        users_by_date.setdefault(report.report_date, set()).add(report.user_id)
        active_days.add(report.report_date)

    for report_date, user_ids in sorted(users_by_date.items()):
        if len(user_ids) >= active_count:
            first_full_day = report_date
            break

    active_day_count = len(active_days)
    support_total = await _support_signals_count(session, group_id)

    progress_by_id = {
        "first_full_day": 1 if first_full_day else 0,
        "week_together": active_day_count,
        "hundred_actions": total_ready,
        "thirty_support": support_total,
    }
    unlocked_at_by_id = {
        "first_full_day": first_full_day.isoformat() if first_full_day else None,
    }

    items = []
    for spec in MILESTONE_SPECS:
        milestone_id = str(spec["id"])
        target = spec["target"]
        current = int(progress_by_id[milestone_id])
        if target is None:
            unlocked = current >= 1
            target_value = 1
        else:
            target_value = int(target)
            unlocked = current >= target_value
        items.append(
            {
                "id": milestone_id,
                "title": spec["title"],
                "description": spec["description"],
                "current": current,
                "target": target_value,
                "unlocked": unlocked,
                "unlocked_at": unlocked_at_by_id.get(milestone_id),
            }
        )

    return {"items": items}


async def first_ready_report_date(session: AsyncSession, group_id: str) -> date | None:
    return await session.scalar(
        select(func.min(HabitReport.report_date)).where(
            HabitReport.group_id == group_id,
            HabitReport.status == "ready",
        )
    )
