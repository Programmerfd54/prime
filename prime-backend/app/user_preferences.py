import json
from datetime import datetime

OFFICIAL_SKILL_IDS = frozenset(
    {
        "live-communication",
        "digital-detox",
        "one-chapter",
        "morning-focus",
        "body-charge",
        "evening-ritual",
    }
)

ONBOARDING_GOAL_IDS = frozenset(
    {
        "lessDistraction",
        "moveMore",
        "readRegularly",
        "betterMorning",
        "eveningRoutine",
        "socialize",
        "betterSleep",
        "lessStress",
        "lessSocialFeed",
        "readInsteadOfFeed",
    }
)

QUIT_COUNT_VALUES = frozenset({"1", "2", "3+"})
ATTEMPT_COUNT_VALUES = frozenset({"1", "2-3", "4+"})
PREFERRED_TIME_OF_DAY_VALUES = frozenset({"morning", "day", "evening"})
SUPPORT_STYLE_VALUES = frozenset({"practical", "gentle", "strict"})


def parse_onboarding_preferences(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return _normalize_onboarding_preferences(parsed)
    except json.JSONDecodeError:
        pass
    return {}


def _normalize_onboarding_preferences(data: dict) -> dict:
    result: dict = {}
    goals: list[str] = []
    raw_goals = data.get("goals")
    if isinstance(raw_goals, list):
        for item in raw_goals:
            if isinstance(item, str) and item in ONBOARDING_GOAL_IDS and item not in goals:
                goals.append(item)

    goal = data.get("goal")
    if isinstance(goal, str) and goal in ONBOARDING_GOAL_IDS:
        result["goal"] = goal
        if goal not in goals:
            goals.insert(0, goal)
    elif goals:
        result["goal"] = goals[0]

    if goals:
        result["goals"] = goals

    skill_id = data.get("selected_skill_id")
    if isinstance(skill_id, str) and skill_id in OFFICIAL_SKILL_IDS:
        result["selected_skill_id"] = skill_id
    completed_at = data.get("completed_at")
    if isinstance(completed_at, str) and completed_at.strip():
        result["completed_at"] = completed_at.strip()
    window = data.get("preferred_action_window")
    if isinstance(window, str) and window.strip():
        result["preferred_action_window"] = window.strip()
    quit_count = data.get("habit_quit_count")
    if isinstance(quit_count, str) and quit_count in QUIT_COUNT_VALUES:
        result["habit_quit_count"] = quit_count
    attempt_count = data.get("habit_attempt_count")
    if isinstance(attempt_count, str) and attempt_count in ATTEMPT_COUNT_VALUES:
        result["habit_attempt_count"] = attempt_count
    time_of_day = data.get("preferred_time_of_day")
    if isinstance(time_of_day, str) and time_of_day in PREFERRED_TIME_OF_DAY_VALUES:
        result["preferred_time_of_day"] = time_of_day
    support_style = data.get("support_style")
    if isinstance(support_style, str) and support_style in SUPPORT_STYLE_VALUES:
        result["support_style"] = support_style
    return result


def merge_onboarding_preferences(existing: dict, incoming: dict) -> dict:
    merged = dict(existing)
    for key in (
        "goal",
        "goals",
        "selected_skill_id",
        "completed_at",
        "preferred_action_window",
        "preferred_time_of_day",
        "support_style",
        "habit_quit_count",
        "habit_attempt_count",
    ):
        if key in incoming and incoming[key] is not None:
            merged[key] = incoming[key]
    return _normalize_onboarding_preferences(merged)


def onboarding_preferences_is_empty(data: dict) -> bool:
    return not any(
        data.get(k) for k in ("goal", "goals", "selected_skill_id", "completed_at")
    )


def serialize_onboarding_preferences(data: dict) -> str:
    return json.dumps(_normalize_onboarding_preferences(data))


def parse_completed_at(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
