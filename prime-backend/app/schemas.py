from datetime import datetime
import json

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from .nicknames import validate_nickname
from .regions import is_valid_region, region_name

DEFAULT_PRIVACY_SETTINGS = {
    "show_bio": True,
    "show_age": True,
    "show_region": True,
    "show_habits": True,
    "show_streak": True,
    "show_achievements": True,
    "show_groups": True,
}


def parse_privacy_settings(raw: str | None) -> dict:
    if not raw:
        return dict(DEFAULT_PRIVACY_SETTINGS)
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            merged = dict(DEFAULT_PRIVACY_SETTINGS)
            merged.update({k: bool(v) for k, v in parsed.items() if k in merged})
            return merged
    except json.JSONDecodeError:
        pass
    return dict(DEFAULT_PRIVACY_SETTINGS)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=120)
    nickname: str = Field(min_length=3, max_length=33)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        return value.strip()

    @field_validator("nickname")
    @classmethod
    def normalize_nickname(cls, value: str) -> str:
        return validate_nickname(value)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if any(ch.isspace() for ch in value):
            raise ValueError("    ")
        if not any(ch.isalpha() for ch in value):
            raise ValueError("      ")
        if not any(ch.isdigit() for ch in value):
            raise ValueError("      ")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str | None = Field(default=None, max_length=128)
    developer_mode: bool = False

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("password")
    @classmethod
    def strip_password(cls, value: str | None) -> str | None:
        return value if value is None else value.strip()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: str
    nickname: str
    email: str
    name: str
    about: str
    photo_url: str | None
    city: str | None
    region_code: str | None
    region_name: str | None = None
    age: int | None
    profile_completed: bool
    prime_points: int
    successful_days: int
    can_create_custom_skills: bool
    streak_shields: int = 0
    shield_pending: bool = False
    privacy_settings: dict = Field(default_factory=dict)
    matrix_user_id: str | None
    is_moderator: bool
    created_at: datetime

    model_config = {"from_attributes": True}

    @model_validator(mode="before")
    @classmethod
    def hydrate_user(cls, data):
        if hasattr(data, "__table__") and hasattr(data, "privacy_settings"):
            payload = {
                c.name: getattr(data, c.name)
                for c in data.__table__.columns
                if c.name != "privacy_settings"
            }
            payload["privacy_settings"] = parse_privacy_settings(
                getattr(data, "privacy_settings")
            )
            return payload
        return data


class GroupCheckInRequest(BaseModel):
    kind: str = Field(min_length=1, max_length=32)

    @field_validator("kind")
    @classmethod
    def validate_kind(cls, value: str) -> str:
        allowed = {"done", "starting", "support", "hard"}
        normalized = value.strip().lower()
        if normalized not in allowed:
            raise ValueError("Недопустимый тип check-in")
        return normalized


class UpdateUserRequest(BaseModel):
    name: str | None = Field(default=None, max_length=120)
    nickname: str | None = Field(default=None, max_length=33)
    about: str | None = Field(default=None, max_length=4000)
    photo_url: str | None = Field(default=None, max_length=500)
    city: str | None = Field(default=None, max_length=120)
    region_code: str | None = Field(default=None, max_length=8)
    age: int | None = Field(default=None, ge=13, le=120)
    privacy_settings: dict | None = None

    @field_validator("name", "about", "city", "region_code", mode="before")
    @classmethod
    def strip_text(cls, value: str | None) -> str | None:
        return value.strip() if isinstance(value, str) else value

    @field_validator("nickname")
    @classmethod
    def normalize_profile_nickname(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_nickname(value)

    @model_validator(mode="after")
    def validate_provided_fields(self) -> "UpdateUserRequest":
        # Partial PATCH: only validate fields present in the request body.
        # Full profile setup sends all required fields; about-only updates
        # (e.g. before joining a team) send just {"about": "..."}.
        if self.name is not None and not self.name:
            raise ValueError("Укажите имя")
        if self.nickname is not None and not self.nickname:
            raise ValueError("Укажите никнейм")
        if self.region_code is not None and not is_valid_region(self.region_code):
            raise ValueError("Выберите область")
        if self.age is not None and (self.age < 13 or self.age > 120):
            raise ValueError("Укажите возраст")
        return self

    def model_dump(self, *args, **kwargs):
        data = super().model_dump(*args, **kwargs)
        if self.region_code:
            # Keep the old field populated for older application builds.
            data["city"] = region_name(self.region_code)
        return data


class UpdateOnboardingPreferencesRequest(BaseModel):
    goal: str | None = None
    goals: list[str] | None = None
    selected_skill_id: str | None = None
    completed_at: str | None = None
    preferred_action_window: str | None = None
    habit_quit_count: str | None = None
    habit_attempt_count: str | None = None

    @field_validator("preferred_action_window")
    @classmethod
    def validate_action_window(cls, value: str | None) -> str | None:
        if value is None:
            return None
        import re

        normalized = value.strip()
        if not re.fullmatch(r"\d{2}:\d{2}-\d{2}:\d{2}", normalized):
            raise ValueError("Формат окна: HH:MM-HH:MM")
        return normalized

    @field_validator("habit_quit_count")
    @classmethod
    def validate_quit_count(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if value not in {"1", "2", "3+"}:
            raise ValueError("Недопустимое значение")
        return value

    @field_validator("habit_attempt_count")
    @classmethod
    def validate_attempt_count(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if value not in {"1", "2-3", "4+"}:
            raise ValueError("Недопустимое значение")
        return value

    @field_validator("goal")
    @classmethod
    def validate_goal(cls, value: str | None) -> str | None:
        if value is None:
            return None
        from .user_preferences import ONBOARDING_GOAL_IDS

        if value not in ONBOARDING_GOAL_IDS:
            raise ValueError("Недопустимая цель онбординга")
        return value

    @field_validator("goals")
    @classmethod
    def validate_goals(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        from .user_preferences import ONBOARDING_GOAL_IDS

        cleaned: list[str] = []
        for item in value:
            if item not in ONBOARDING_GOAL_IDS:
                raise ValueError("Недопустимая цель онбординга")
            if item not in cleaned:
                cleaned.append(item)
        return cleaned

    @field_validator("selected_skill_id")
    @classmethod
    def validate_skill(cls, value: str | None) -> str | None:
        if value is None:
            return None
        from .user_preferences import OFFICIAL_SKILL_IDS

        if value not in OFFICIAL_SKILL_IDS:
            raise ValueError("Недопустимая программа")
        return value


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, value: str) -> str:
        if any(ch.isspace() for ch in value):
            raise ValueError("    ")
        if not any(ch.isalpha() for ch in value):
            raise ValueError("      ")
        if not any(ch.isdigit() for ch in value):
            raise ValueError("      ")
        return value


class ForgotPasswordRequest(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=16, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("token")
    @classmethod
    def strip_token(cls, value: str) -> str:
        return value.strip()

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, value: str) -> str:
        if any(ch.isspace() for ch in value):
            raise ValueError("    ")
        if not any(ch.isalpha() for ch in value):
            raise ValueError("      ")
        if not any(ch.isdigit() for ch in value):
            raise ValueError("      ")
        return value


class HealthResponse(BaseModel):
    status: str
