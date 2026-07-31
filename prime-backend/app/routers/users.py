from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
import json
import secrets

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import get_current_user
from ..media import read_upload
from ..object_storage import delete_media, storage_configured, store_media
from ..audit import record_audit
from ..models import (
    DeviceToken,
    Group,
    GroupDay,
    GroupMember,
    HabitReport,
    MediaUpload,
    ModerationAppeal,
    ModerationDecision,
    PrimeEvent,
    User,
    UserRestriction,
    UserSkillFavorite,
    utcnow,
)
from ..metrics_engine import (
    report_gap_days,
    skills_breakdown,
    streak_snapshot,
)
from ..skills_catalog import skill_name
from ..team_day import team_completed_dates, team_pending_dates
from ..nicknames import validate_nickname
from ..regions import is_valid_region
from ..moderation import ModerationError, check_social_write_allowed, moderate_text_before_publish
from ..moderation.pipeline import moderation_http_error
from ..schemas import (
    DEFAULT_PRIVACY_SETTINGS,
    ChangePasswordRequest,
    EmailPreferencesResponse,
    UpdateEmailPreferencesRequest,
    UpdateOnboardingPreferencesRequest,
    UpdateUserRequest,
    UserResponse,
    parse_privacy_settings,
)
from ..user_preferences import (
    OFFICIAL_SKILL_IDS,
    merge_onboarding_preferences,
    parse_onboarding_preferences,
    serialize_onboarding_preferences,
)
from ..security import hash_password, verify_password
from ..sessions import revoke_user_sessions


router = APIRouter(prefix="/users", tags=["users"])
legacy_router = APIRouter(tags=["users"])
AVATAR_DIR = Path("uploads/avatars")
MAX_AVATAR_BYTES = 5 * 1024 * 1024
ALLOWED_AVATAR_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


def _profile_is_complete(user: User) -> bool:
    return bool(
        (user.name or "").strip()
        and (user.nickname or "").strip()
        and is_valid_region(user.region_code)
        and user.age is not None
    )


@router.get("/me", response_model=UserResponse)
async def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.get("/{user_id}/avatar/{filename}")
async def get_avatar(
    user_id: str,
    filename: str,
    viewer: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    target = await session.scalar(select(User).where(User.id == user_id, User.is_active.is_(True)))
    if target is None or not target.photo_url or Path(filename).name != filename:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Аватар не найден")
    if not target.photo_url.endswith(f"/{filename}"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Аватар не найден")
    path = AVATAR_DIR / filename
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Аватар не найден")
    media_type = {".jpg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}.get(path.suffix.lower(), "application/octet-stream")
    return Response(
        content=path.read_bytes(),
        media_type=media_type,
        headers={
            "Cache-Control": "private, max-age=300",
            "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
            "X-Content-Type-Options": "nosniff",
        },
    )


@legacy_router.get("/uploads/avatars/{filename}")
async def get_legacy_avatar(
    filename: str,
    viewer: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """Serve pre-private avatar URLs without re-introducing a public mount."""
    if Path(filename).name != filename:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Аватар не найден")
    target = await session.scalar(
        select(User).where(
            User.photo_url == f"/uploads/avatars/{filename}",
            User.is_active.is_(True),
        )
    )
    path = AVATAR_DIR / filename
    if target is None or not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Аватар не найден")
    media_type = {".jpg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}.get(
        path.suffix.lower(), "application/octet-stream"
    )
    return Response(
        content=path.read_bytes(),
        media_type=media_type,
        headers={
            "Cache-Control": "private, max-age=300",
            "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.get("/me/stats")
async def my_stats(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    first_membership_at = await session.scalar(
        select(func.min(GroupMember.created_at)).where(GroupMember.user_id == user.id)
    )
    tracking_start = (
        first_membership_at.date() if first_membership_at is not None else None
    )
    completed_team_dates = await team_completed_dates(session, user.id)
    pending_team_dates = await team_pending_dates(session, user.id)

    ready_dates = set(
        (
            await session.execute(
                select(HabitReport.report_date)
                .where(
                    HabitReport.user_id == user.id,
                    HabitReport.status == "ready",
                )
                .distinct()
            )
        ).scalars().all()
    )

    metrics = streak_snapshot(
        completed_team_dates,
        tracking_start=tracking_start,
        successful_days=user.successful_days,
        prime_points=user.prime_points,
        shield_pending=user.shield_pending,
        neutral=pending_team_dates,
    )

    completed_reports = (
        await session.execute(
            select(HabitReport, Group)
            .join(Group, Group.id == HabitReport.group_id)
            .join(
                GroupDay,
                (GroupDay.group_id == HabitReport.group_id)
                & (GroupDay.day_date == HabitReport.report_date),
            )
            .where(
                HabitReport.user_id == user.id,
                HabitReport.status == "ready",
                GroupDay.status == "complete",
            )
        )
    ).all()
    skill_entries = [
        (
            group.skill_id,
            skill_name(group.skill_id),
        )
        for _report, group in completed_reports
    ]

    return {
        "current_streak": metrics["current_streak"],
        "best_streak": metrics["best_streak"],
        "successful_days": user.successful_days,
        "prime_points": user.prime_points,
        "cycle_pace_percent": metrics["cycle_pace_percent"],
        "report_gap_days": report_gap_days(ready_dates, completed_team_dates),
        "skills_breakdown": skills_breakdown(skill_entries),
    }


@router.patch("/me", response_model=UserResponse)
async def update_me(
    payload: UpdateUserRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> User:
    data = payload.model_dump(exclude_unset=True)
    # Avatars are set only via POST /me/avatar — reject client-supplied URLs.
    data.pop("photo_url", None)
    if "region_code" in data and not is_valid_region(data["region_code"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="   ",
        )
    if "timezone" in data:
        from ..timezone_utils import normalize_timezone

        normalized = normalize_timezone(data.get("timezone"))
        if data["timezone"] is not None and normalized is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Недопустимый часовой пояс",
            )
        data["timezone"] = normalized
    if "nickname" in data:
        nickname = validate_nickname(data["nickname"])
        existing = await session.scalar(select(User).where(User.nickname == nickname, User.id != user.id))
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="  ",
            )
        data["nickname"] = nickname

    if "privacy_settings" in data:
        merged = parse_privacy_settings(user.privacy_settings)
        incoming = data.pop("privacy_settings")
        if isinstance(incoming, dict):
            for key in DEFAULT_PRIVACY_SETTINGS:
                if key in incoming:
                    merged[key] = bool(incoming[key])
        data["privacy_settings"] = json.dumps(merged)

    social_fields = ("name", "nickname", "about")
    if any(field in data for field in social_fields):
        try:
            await check_social_write_allowed(session, user)
        except ModerationError as exc:
            raise moderation_http_error(exc) from exc
        for field in social_fields:
            if field in data and isinstance(data[field], str) and data[field].strip():
                try:
                    await moderate_text_before_publish(
                        session,
                        user=user,
                        text=data[field],
                        content_type=f"profile_{field}",
                    )
                except ModerationError as exc:
                    raise moderation_http_error(exc) from exc

    for key, value in data.items():
        setattr(user, key, value)

    if _profile_is_complete(user):
        user.profile_completed = True
    session.add(user)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="  ",
        ) from None
    await session.refresh(user)
    return user


@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> User:
    content, content_type, _ = await read_upload(
        file,
        max_bytes=MAX_AVATAR_BYTES,
        max_image_bytes=MAX_AVATAR_BYTES,
        allow_types=set(ALLOWED_AVATAR_TYPES),
    )
    extension = ALLOWED_AVATAR_TYPES[content_type]

    if storage_configured():
        old_url = user.photo_url
        stored_url = await store_media(
            data=content,
            user_id=user.id,
            scope_type="avatar",
            filename=f"avatar{extension}",
            content_type=content_type,
        )
        user.photo_url = stored_url
        session.add(user)
        try:
            await session.commit()
        except Exception:
            await session.rollback()
            await delete_media(stored_url, user_id=user.id)
            raise
        await session.refresh(user)
        await delete_media(old_url, user_id=user.id)
        return user

    AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{user.id}-{uuid4().hex}{extension}"
    path = AVATAR_DIR / filename
    path.write_bytes(content)

    old_path = None
    if user.photo_url and "/avatar/" in user.photo_url:
        old_path = AVATAR_DIR / Path(user.photo_url.rsplit("/", 1)[-1]).name
    elif user.photo_url and user.photo_url.startswith("/uploads/avatars/"):
        old_path = AVATAR_DIR / Path(user.photo_url).name

    user.photo_url = f"/api/v1/users/{user.id}/avatar/{filename}"
    session.add(user)
    await session.commit()
    await session.refresh(user)
    if old_path is not None and old_path != path and old_path.exists():
        old_path.unlink()
    return user


@router.delete("/me/avatar", response_model=UserResponse)
async def delete_avatar(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> User:
    old_url = user.photo_url
    old_path = None
    if user.photo_url and "/avatar/" in user.photo_url:
        old_path = AVATAR_DIR / Path(user.photo_url.rsplit("/", 1)[-1]).name
    elif user.photo_url and user.photo_url.startswith("/uploads/avatars/"):
        old_path = AVATAR_DIR / Path(user.photo_url).name
    user.photo_url = None
    session.add(user)
    await session.commit()
    await session.refresh(user)
    if old_path is not None and old_path.exists():
        old_path.unlink()
    await delete_media(old_url, user_id=user.id)
    return user


@router.post("/me/password", status_code=204)
async def change_password(
    payload: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="   ",
        )
    if payload.current_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="     ",
        )

    user.password_hash = hash_password(payload.new_password)
    await revoke_user_sessions(session, user.id)
    session.add(user)
    await session.commit()
    return None


@router.get("/me/preferences")
async def get_preferences(user: User = Depends(get_current_user)) -> dict:
    return parse_onboarding_preferences(user.onboarding_preferences)


@router.patch("/me/preferences")
async def update_preferences(
    payload: UpdateOnboardingPreferencesRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    merged = merge_onboarding_preferences(
        parse_onboarding_preferences(user.onboarding_preferences),
        payload.model_dump(exclude_unset=True),
    )
    user.onboarding_preferences = serialize_onboarding_preferences(merged)
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return merged


@router.get("/me/email-preferences", response_model=EmailPreferencesResponse)
async def get_email_preferences(
    user: User = Depends(get_current_user),
) -> EmailPreferencesResponse:
    return EmailPreferencesResponse(marketing_emails_opt_in=user.marketing_emails_opt_in)


@router.patch("/me/email-preferences", response_model=EmailPreferencesResponse)
async def update_email_preferences(
    payload: UpdateEmailPreferencesRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> EmailPreferencesResponse:
    user.marketing_emails_opt_in = payload.marketing_emails_opt_in
    if payload.marketing_emails_opt_in:
        user.marketing_emails_unsubscribed_at = None
    else:
        user.marketing_emails_unsubscribed_at = utcnow()
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return EmailPreferencesResponse(marketing_emails_opt_in=user.marketing_emails_opt_in)


@router.get("/me/favorites")
async def list_favorites(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    rows = await session.execute(
        select(UserSkillFavorite.skill_id)
        .where(UserSkillFavorite.user_id == user.id)
        .order_by(UserSkillFavorite.created_at.asc())
    )
    return {"skill_ids": list(rows.scalars().all())}


@router.post("/me/favorites/{skill_id}", status_code=201)
async def add_favorite(
    skill_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if skill_id not in OFFICIAL_SKILL_IDS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Неизвестная программа",
        )
    existing = await session.scalar(
        select(UserSkillFavorite).where(
            UserSkillFavorite.user_id == user.id,
            UserSkillFavorite.skill_id == skill_id,
        )
    )
    if existing is None:
        session.add(UserSkillFavorite(user_id=user.id, skill_id=skill_id))
        await session.commit()
    return {"skill_id": skill_id}


@router.delete("/me/favorites/{skill_id}", status_code=204)
async def remove_favorite(
    skill_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    row = await session.scalar(
        select(UserSkillFavorite).where(
            UserSkillFavorite.user_id == user.id,
            UserSkillFavorite.skill_id == skill_id,
        )
    )
    if row is not None:
        await session.delete(row)
        await session.commit()
    return None


@router.get("/me/prime-events")
async def list_prime_events(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    rows = await session.execute(
        select(PrimeEvent)
        .where(PrimeEvent.user_id == user.id)
        .order_by(PrimeEvent.created_at.desc())
        .limit(100)
    )
    return [
        {
            "id": item.id,
            "amount": item.amount,
            "reason": item.reason,
            "skill_id": item.skill_id,
            "group_id": item.group_id,
            "created_at": item.created_at.isoformat(),
        }
        for item in rows.scalars().all()
    ]


SHIELD_COST = 5


@router.post("/me/shields/use")
async def use_streak_shield(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if user.shield_pending:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Щит уже активирован",
        )
    if user.streak_shields <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нет доступных щитов",
        )
    user.streak_shields -= 1
    user.shield_pending = True
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return {
        "streak_shields": user.streak_shields,
        "shield_pending": user.shield_pending,
    }


@router.post("/me/shields/buy")
async def buy_streak_shield(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if user.prime_points < SHIELD_COST:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Недостаточно Праймов",
        )
    user.prime_points -= SHIELD_COST
    user.streak_shields += 1
    session.add(
        PrimeEvent(
            user_id=user.id,
            amount=-SHIELD_COST,
            reason="Покупка щита серии",
        )
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return {
        "streak_shields": user.streak_shields,
        "prime_points": user.prime_points,
    }


@router.delete("/me", status_code=204)
async def delete_me(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> None:
    old_avatar = None
    if user.photo_url and "/avatar/" in user.photo_url:
        old_avatar = AVATAR_DIR / Path(user.photo_url.rsplit("/", 1)[-1]).name
    await revoke_user_sessions(session, user.id)
    await session.execute(delete(DeviceToken).where(DeviceToken.user_id == user.id))
    await session.execute(delete(MediaUpload).where(MediaUpload.owner_user_id == user.id))
    await session.execute(delete(UserRestriction).where(UserRestriction.user_id == user.id))
    await session.execute(delete(ModerationAppeal).where(ModerationAppeal.user_id == user.id))
    await session.execute(delete(ModerationDecision).where(ModerationDecision.actor_user_id == user.id))
    await record_audit(session, action="account.deleted", user_id=user.id)
    ts = int(datetime.now(timezone.utc).timestamp())
    user.email = f"deleted+{ts}+{user.id}@deleted.local"
    user.nickname = f"deleted_{user.id[:8]}"
    user.is_active = False
    user.password_hash = hash_password(secrets.token_hex(32))
    user.name = "Удалённый аккаунт"
    user.about = ""
    user.photo_url = None
    user.matrix_access_token = None
    session.add(user)
    await session.commit()
    if old_avatar is not None and old_avatar.exists():
        old_avatar.unlink()
    return None
