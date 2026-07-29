from datetime import date, timedelta

import pytest

from app.metrics_engine import (
    best_consecutive_streak,
    build_user_insights,
    current_consecutive_streak,
    cycle_pace_percent,
    streak_snapshot,
)


def d(offset: int) -> date:
    return date.today() - timedelta(days=offset)


def test_current_streak_requires_consecutive_days() -> None:
    completed = {d(0), d(1), d(2)}
    assert current_consecutive_streak(completed)[0] == 3

    gap = {d(0), d(2)}
    assert current_consecutive_streak(gap)[0] == 1

    assert current_consecutive_streak(set())[0] == 0


def test_shield_allows_one_gap() -> None:
    gap = {d(0), d(2), d(3)}
    streak, used = current_consecutive_streak(gap, allow_one_gap=True)
    assert streak == 3
    assert used is True


def test_best_streak_finds_longest_run() -> None:
    completed = {d(10), d(9), d(8), d(5), d(4)}
    assert best_consecutive_streak(completed) == 3


def test_cycle_pace_percent_last_30_days() -> None:
    completed = {d(i) for i in range(0, 15)}
    pace = cycle_pace_percent(completed, tracking_start=d(29), today=d(0))
    assert pace == 50


def test_insights_require_minimum_history() -> None:
    assert build_user_insights(
        current_streak=0,
        best_streak=0,
        successful_days=2,
        prime_points=2,
        cycle_pace_percent=None,
        reports_last_7=2,
        reports_prev_7=1,
    ) == []


def test_neutral_days_bridge_streak() -> None:
    completed = {d(0), d(2)}
    neutral = {d(1)}
    streak, _ = current_consecutive_streak(completed, neutral=neutral)
    assert streak == 2
    assert best_consecutive_streak(completed, neutral=neutral) == 2


def test_insights_include_streak_momentum() -> None:
    items = build_user_insights(
        current_streak=4,
        best_streak=4,
        successful_days=10,
        prime_points=10,
        cycle_pace_percent=40,
        reports_last_7=4,
        reports_prev_7=3,
    )
    assert any(item["id"] == "streak_momentum" for item in items)


def test_streak_snapshot_shape() -> None:
    completed = {d(0), d(1), d(2), d(3)}
    snapshot = streak_snapshot(
        completed,
        tracking_start=d(30),
        successful_days=4,
        prime_points=4,
    )
    assert snapshot["current_streak"] == 4
    assert snapshot["best_streak"] == 4
    assert isinstance(snapshot["insights"], list)
