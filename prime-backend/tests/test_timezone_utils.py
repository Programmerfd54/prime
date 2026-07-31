"""Tests for team reporting day timezone resolution."""

from __future__ import annotations

import pytest

from app.models import Group
from app.timezone_utils import (
    fallback_timezone_for_group,
    group_today,
    normalize_timezone,
    team_day_window,
)


def test_normalize_timezone_accepts_iana():
    assert normalize_timezone("Europe/Moscow") == "Europe/Moscow"
    assert normalize_timezone("  UTC  ") == "UTC"


def test_normalize_timezone_rejects_invalid():
    assert normalize_timezone("Not/AZone") is None
    assert normalize_timezone("") is None


def test_fallback_ru_region_defaults_moscow():
    group = Group(name="G", skill_id="morning-focus", region_code="77")
    assert fallback_timezone_for_group(group) == "Europe/Moscow"


def test_fallback_non_ru_defaults_utc():
    group = Group(name="G", skill_id="morning-focus", region_code=None)
    assert fallback_timezone_for_group(group) == "UTC"


def test_team_day_window_closes_at_end_of_local_day():
    window = team_day_window("Europe/Moscow", group_today(Group(name="G", skill_id="x", region_code="77")))
    assert window["closes_at"].tzinfo is not None
    assert window["day_end"] > window["day_start"]
