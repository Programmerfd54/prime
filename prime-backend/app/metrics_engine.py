from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import GroupMember, HabitReport

INSIGHT_MIN_DAYS = 3
ACHIEVEMENT_THRESHOLDS = (30, 90, 365)


def current_consecutive_streak(
    completed: set[date],
    *,
    today: date | None = None,
    allow_one_gap: bool = False,
    neutral: set[date] | None = None,
) -> tuple[int, bool]:
    """Return (streak, gap_consumed).

    `neutral` dates (user reported but team day not complete) neither extend
    nor break the streak — they are skipped like a soft pause.
    """
    if not completed and not neutral:
        return 0, False
    today = today or date.today()
    neutral = neutral or set()

    # Anchor: today if completed, else yesterday if completed, else today if
    # neutral (pause), else yesterday if neutral.
    if today in completed:
        anchor = today
    elif today - timedelta(days=1) in completed:
        anchor = today - timedelta(days=1)
    elif today in neutral:
        anchor = today
    elif today - timedelta(days=1) in neutral:
        anchor = today - timedelta(days=1)
    elif allow_one_gap:
        anchor = today if today in completed or today in neutral else today - timedelta(days=1)
        if anchor not in completed and anchor not in neutral:
            return 0, False
    else:
        return 0, False

    streak = 0
    cursor = anchor
    gap_left = allow_one_gap
    gap_used = False
    # Walk back; skip neutrals without counting them.
    safety = 0
    while safety < 4000:
        safety += 1
        if cursor in completed:
            streak += 1
            cursor -= timedelta(days=1)
        elif cursor in neutral:
            cursor -= timedelta(days=1)
        elif gap_left:
            gap_left = False
            gap_used = True
            cursor -= timedelta(days=1)
        else:
            break
    return streak, gap_used


def best_consecutive_streak(
    completed: set[date],
    *,
    neutral: set[date] | None = None,
) -> int:
    """Longest consecutive run, treating neutral days as bridges."""
    if not completed:
        return 0
    neutral = neutral or set()
    # Expand searchable set: completed counts, neutrals bridge.
    best = 0
    for day in completed:
        # Start of a run: previous day is neither completed nor neutral.
        prev = day - timedelta(days=1)
        if prev in completed or prev in neutral:
            # Might still be a start if we walked through neutrals from an
            # earlier completed day — only skip if prev is completed.
            if prev in completed:
                continue
            # Walk back through neutrals; if we hit a completed, this isn't a start.
            cursor = prev
            bridged = False
            while cursor in neutral:
                cursor -= timedelta(days=1)
                bridged = True
            if bridged and cursor in completed:
                continue
        run = 0
        cursor = day
        while True:
            if cursor in completed:
                run += 1
                cursor += timedelta(days=1)
            elif cursor in neutral:
                cursor += timedelta(days=1)
            else:
                break
        best = max(best, run)
    return best


def cycle_pace_percent(
    completed: set[date],
    *,
    tracking_start: date | None,
    today: date | None = None,
    window_days: int = 30,
) -> int | None:
    if not completed:
        return None
    today = today or date.today()
    window_start = today - timedelta(days=window_days - 1)
    if tracking_start is not None:
        window_start = max(window_start, tracking_start)
    days_in_window = (today - window_start).days + 1
    if days_in_window <= 0:
        return None
    completed_in_window = sum(
        1 for day in completed if window_start <= day <= today
    )
    return round(completed_in_window / days_in_window * 100)


def ready_reports_in_range(
    completed: set[date],
    *,
    end: date,
    span_days: int,
) -> int:
    start = end - timedelta(days=span_days - 1)
    return sum(1 for day in completed if start <= day <= end)


def report_gap_days(
    reported_ready: set[date],
    completed: set[date],
) -> int:
    """Days where the user reported ready but the team day is not complete."""
    return len(reported_ready - completed)


def skills_breakdown(
    entries: list[tuple[str, str]],
) -> list[dict[str, str | int]]:
    """Aggregate completed counts per skill from (skill_id, skill_name) pairs."""
    counts: dict[str, dict[str, str | int]] = {}
    for skill_id, skill_name in entries:
        if skill_id not in counts:
            counts[skill_id] = {
                "skill_id": skill_id,
                "skill_name": skill_name,
                "completed": 0,
            }
        counts[skill_id]["completed"] = int(counts[skill_id]["completed"]) + 1
    return sorted(
        counts.values(),
        key=lambda item: int(item["completed"]),
        reverse=True,
    )


def achievement_awarded_at(
    *,
    required_days: int,
    unlocked: bool,
    completed_dates: list[date],
    fallback: datetime | None = None,
) -> str | None:
    if not unlocked:
        return None
    if len(completed_dates) >= required_days:
        day = completed_dates[required_days - 1]
        return datetime.combine(day, datetime.min.time(), tzinfo=timezone.utc).isoformat()
    if fallback is not None:
        return fallback.isoformat()
    return datetime.now(timezone.utc).isoformat()


def build_user_insights(
    *,
    current_streak: int,
    best_streak: int,
    successful_days: int,
    prime_points: int,
    cycle_pace_percent: int | None,
    reports_last_7: int,
    reports_prev_7: int,
) -> list[dict[str, str]]:
    if successful_days < INSIGHT_MIN_DAYS:
        return []

    items: list[dict[str, str]] = []

    if current_streak >= 3:
        items.append(
            {
                "id": "streak_momentum",
                "kind": "streak",
                "title": "Серия набирает силу",
                "message": f"У вас {current_streak} полных командных дней подряд.",
            }
        )
    elif current_streak == 0:
        items.append(
            {
                "id": "streak_restart",
                "kind": "streak",
                "title": "Можно начать новую серию",
                "message": "Сегодня хороший день, чтобы вернуться в ежедневный ритм.",
            }
        )

    if prime_points > successful_days:
        items.append(
            {
                "id": "multi_group_days",
                "kind": "primes",
                "title": "Несколько привычек в один день",
                "message": (
                    f"Праймов ({prime_points}) больше, чем успешных дней "
                    f"({successful_days}) — вы иногда закрываете несколько программ."
                ),
            }
        )

    if cycle_pace_percent is not None and successful_days >= 7:
        items.append(
            {
                "id": "cycle_pace",
                "kind": "cycle",
                "title": "Темп последних 30 дней",
                "message": f"За последний месяц команда закрыла {cycle_pace_percent}% дней.",
            }
        )

    if reports_last_7 > reports_prev_7 and reports_prev_7 > 0:
        items.append(
            {
                "id": "week_up",
                "kind": "trend",
                "title": "Неделя сильнее",
                "message": (
                    f"На этой неделе {reports_last_7} полных дней против "
                    f"{reports_prev_7} на прошлой."
                ),
            }
        )
    elif reports_last_7 < reports_prev_7 and reports_prev_7 >= 3:
        items.append(
            {
                "id": "week_down",
                "kind": "trend",
                "title": "Темп можно поднять",
                "message": (
                    f"На прошлой неделе было {reports_prev_7} полных дней — "
                    f"сейчас {reports_last_7}."
                ),
            }
        )

    for threshold in ACHIEVEMENT_THRESHOLDS:
        if successful_days < threshold and successful_days >= threshold - 5:
            remaining = threshold - successful_days
            items.append(
                {
                    "id": f"near_{threshold}",
                    "kind": "achievement",
                    "title": f"До {threshold} дней",
                    "message": f"Осталось {remaining} успешных дней до следующего рубежа.",
                }
            )
            break

    if best_streak >= 5 and best_streak > current_streak:
        items.append(
            {
                "id": "best_streak",
                "kind": "streak",
                "title": "Ваш рекорд серии",
                "message": f"Лучшая серия — {best_streak} полных дней подряд.",
            }
        )

    return items[:4]


async def load_completed_dates(
    session: AsyncSession,
    user_id: str,
    *,
    group_id: str | None = None,
) -> set[date]:
    """Legacy helper — individual ready dates. Prefer team_completed_dates."""
    filters = [
        HabitReport.user_id == user_id,
        HabitReport.status == "ready",
    ]
    if group_id is not None:
        filters.append(HabitReport.group_id == group_id)
    rows = await session.execute(
        select(HabitReport.report_date).where(*filters).distinct()
    )
    return {row[0] for row in rows.all()}


async def sync_group_member_streak(
    session: AsyncSession,
    membership: GroupMember,
    *,
    group_id: str,
    user_id: str,
    today: date | None = None,
) -> None:
    from .team_day import team_completed_dates, team_pending_dates

    completed = await team_completed_dates(session, user_id, group_id=group_id)
    neutral = await team_pending_dates(session, user_id, group_id=group_id)
    current, _ = current_consecutive_streak(
        completed, today=today, neutral=neutral
    )
    best = best_consecutive_streak(completed, neutral=neutral)
    membership.streak = current
    membership.best_streak = best
    session.add(membership)


def streak_snapshot(
    completed: set[date],
    *,
    tracking_start: date | None = None,
    today: date | None = None,
    successful_days: int = 0,
    prime_points: int = 0,
    shield_pending: bool = False,
    neutral: set[date] | None = None,
) -> dict:
    today = today or date.today()
    current, gap_used = current_consecutive_streak(
        completed,
        today=today,
        allow_one_gap=shield_pending,
        neutral=neutral,
    )
    best = best_consecutive_streak(completed, neutral=neutral)
    pace = cycle_pace_percent(
        completed,
        tracking_start=tracking_start,
        today=today,
    )
    last_7 = ready_reports_in_range(completed, end=today, span_days=7)
    prev_7_end = today - timedelta(days=7)
    prev_7 = ready_reports_in_range(completed, end=prev_7_end, span_days=7)
    insights = build_user_insights(
        current_streak=current,
        best_streak=best,
        successful_days=successful_days,
        prime_points=prime_points,
        cycle_pace_percent=pace,
        reports_last_7=last_7,
        reports_prev_7=prev_7,
    )
    return {
        "current_streak": current,
        "best_streak": best,
        "cycle_pace_percent": pace,
        "insights": insights,
        "shield_gap_used": gap_used,
    }
