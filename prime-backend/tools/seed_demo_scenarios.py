#!/usr/bin/env python3
"""Deterministic dev-only demo scenarios for PRIME visual gate screenshots.

Usage:
  ALLOW_DEMO_SEED=1 python3 tools/seed_demo_scenarios.py --yes
  ALLOW_DEMO_SEED=1 python3 tools/seed_demo_scenarios.py --yes --reset

Creates three @prime.local accounts:
  demo.empty@prime.local    — brand-new user, no habit/team
  demo.matching@prime.local — waiting room, partial match, invited friend
  demo.filled@prime.local   — day 22/30, full team, rich history (primary gate account)

Re-runs are idempotent (upsert by email). Metrics derive from seeded reports via
team_day + metrics_engine — never hardcoded on User rows.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import shutil
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4

from sqlalchemy import delete, select

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.db import SessionLocal  # noqa: E402
from app.metrics_engine import sync_group_member_streak  # noqa: E402
from app.models import (  # noqa: E402
    ChatMessage,
    ChatMessageReaction,
    DirectConversationRead,
    DirectMessage,
    DirectMessageReaction,
    FriendRequest,
    Friendship,
    Group,
    GroupDay,
    GroupMember,
    HabitReport,
    Notification,
    PrimeEvent,
    User,
    UserSkillFavorite,
    WaitingRoomEntry,
)
from app.routers.group_service import (  # noqa: E402
    _direct_conversation_key,
    _friendship_pair,
    _sync_user_daily_progress,
)
from app.security import hash_password  # noqa: E402
from app.team_day import (  # noqa: E402
    award_team_day_primes,
    recompute_group_day,
)
from app.user_preferences import serialize_onboarding_preferences  # noqa: E402

PASSWORD = "DemoPrime123!"
DEMO_DOMAIN = "@example.com"
SKILL_ID = "morning-focus"
REGION = "77"
ALLOWED_DB_HOSTS = frozenset({"localhost", "127.0.0.1", "prime-postgres"})
PROD_MARKERS = ("inpr1me.ru", "2.26.86.88")

def _avatar_src_dir() -> Path:
    candidates = (
        ROOT.parent / "prime-flutter" / "assets" / "avatars" / "demo",
        Path("/app/demo_avatars"),
        ROOT / "demo_avatars",
    )
    for path in candidates:
        if path.is_dir():
            return path
    return candidates[0]


AVATAR_DST = ROOT / "uploads" / "avatars"

ACCOUNTS = {
    "empty": {
        "email": f"demo-empty{DEMO_DOMAIN}",
        "nickname": "demoempty",
        "name": "Аня Новая",
        "about": "",
        "avatar": "a1",
    },
    "matching": {
        "email": f"demo-matching{DEMO_DOMAIN}",
        "nickname": "demomatch",
        "name": "Кирилл Ж.",
        "about": "Ищу команду для утреннего фокуса. Люблю спокойный ритм и честную обратную связь.",
        "avatar": "a2",
    },
    "filled": {
        "email": f"demo-filled{DEMO_DOMAIN}",
        "nickname": "demofilled",
        "name": "Мария К.",
        "about": (
            "Утренний ритм · команда · маленькие шаги каждый день. "
            "22-й день цикла — держим темп вместе."
        ),
        "avatar": "a3",
    },
}

TEAMMATES = [
    ("demo-tm1@example.com", "demotm1", "Игорь", "a1"),
    ("demo-tm2@example.com", "demotm2", "Мила", "a4"),
    ("demo-tm3@example.com", "demotm3", "Саша", "a2"),
    ("demo-tm4@example.com", "demotm4", "Лена", "a5"),
    ("demo-tm5@example.com", "demotm5", "Олег", "a1"),
]

WAITING_PEERS = [
    ("demo-wait1@example.com", "demow1", "Полина"),
    ("demo-wait2@example.com", "demow2", "Артём"),
    ("demo-wait3@example.com", "demow3", "Нина"),
]

INVITED_FRIEND = ("demo-friend@example.com", "demofriend", "Даша", "a5")


def _assert_safe_to_run(yes: bool) -> None:
    if os.environ.get("ALLOW_DEMO_SEED") != "1":
        raise SystemExit(
            "Refusing to seed: set ALLOW_DEMO_SEED=1 in the environment."
        )
    if not yes:
        raise SystemExit("Refusing to seed: pass --yes to confirm.")

    db_url = os.environ.get("DATABASE_URL", "")
    if not db_url:
        from app.config import get_settings

        db_url = get_settings().database_url

    lowered = db_url.lower()
    for marker in PROD_MARKERS:
        if marker in lowered:
            raise SystemExit(f"Refusing to seed: production marker {marker!r} in DATABASE_URL.")

    host = urlparse(db_url.replace("+asyncpg", "")).hostname or ""
    if host not in ALLOWED_DB_HOSTS:
        raise SystemExit(
            f"Refusing to seed: DATABASE_URL host {host!r} not in allowlist "
            f"{sorted(ALLOWED_DB_HOSTS)}."
        )


def _copy_avatar(key: str) -> str | None:
    src = _avatar_src_dir() / f"{key}.jpg"
    if not src.is_file():
        print(f"  warning: avatar fixture missing {src}")
        return None
    AVATAR_DST.mkdir(parents=True, exist_ok=True)
    filename = f"demo-{key}.jpg"
    dst = AVATAR_DST / filename
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        shutil.copy2(src, dst)
    return f"/uploads/avatars/{filename}"


async def _upsert_user(
    session,
    *,
    email: str,
    nickname: str,
    name: str,
    about: str = "",
    avatar_key: str | None = None,
    profile_completed: bool = False,
    onboarding: dict | None = None,
    region_code: str | None = None,
    city: str | None = None,
    age: int | None = None,
) -> User:
    user = await session.scalar(select(User).where(User.email == email))
    photo_url = _copy_avatar(avatar_key) if avatar_key else None
    prefs = serialize_onboarding_preferences(onboarding or {})
    if user is None:
        user = User(
            email=email,
            password_hash=hash_password(PASSWORD),
            nickname=nickname,
            name=name,
            about=about,
            photo_url=photo_url,
            region_code=region_code,
            city=city,
            age=age,
            profile_completed=profile_completed,
            onboarding_preferences=prefs,
            # Seeded accounts skip the email confirmation step so they can log in.
            email_verified_at=datetime.now(timezone.utc),
        )
        session.add(user)
    else:
        if user.email_verified_at is None:
            user.email_verified_at = datetime.now(timezone.utc)
        user.nickname = nickname
        user.name = name
        user.about = about
        user.profile_completed = profile_completed
        user.onboarding_preferences = prefs
        if photo_url:
            user.photo_url = photo_url
        if region_code:
            user.region_code = region_code
        if city:
            user.city = city
        if age:
            user.age = age
        session.add(user)
    await session.flush()
    return user


async def _delete_demo_users(session) -> int:
    emails = [a["email"] for a in ACCOUNTS.values()]
    emails.extend(t[0] for t in TEAMMATES)
    emails.extend(w[0] for w in WAITING_PEERS)
    emails.append(INVITED_FRIEND[0])
    # Legacy @prime.local accounts from earlier seeder runs.
    emails.extend(
        e.replace("@example.com", "@prime.local")
        for e in list(emails)
        if "@example.com" in e
    )

    users_by_email = (
        await session.execute(select(User).where(User.email.in_(emails)))
    ).scalars().all()
    users_by_nick = (
        await session.execute(
            select(User).where(
                User.nickname.in_(
                    [a["nickname"] for a in ACCOUNTS.values()]
                    + [t[1] for t in TEAMMATES]
                    + [w[1] for w in WAITING_PEERS]
                    + [INVITED_FRIEND[1]]
                )
            )
        )
    ).scalars().all()
    users = {u.id: u for u in [*users_by_email, *users_by_nick]}.values()
    if not users:
        return 0

    user_ids = [u.id for u in users]

    for model, col in (
        (DirectMessageReaction, DirectMessageReaction.user_id),
        (DirectMessageReaction, DirectMessageReaction.message_id),
        (ChatMessageReaction, ChatMessageReaction.user_id),
        (DirectConversationRead, DirectConversationRead.user_id),
        (HabitReport, HabitReport.user_id),
        (GroupMember, GroupMember.user_id),
        (WaitingRoomEntry, WaitingRoomEntry.user_id),
        (Notification, Notification.user_id),
        (PrimeEvent, PrimeEvent.user_id),
        (UserSkillFavorite, UserSkillFavorite.user_id),
        (FriendRequest, FriendRequest.requester_user_id),
        (FriendRequest, FriendRequest.addressee_user_id),
    ):
        await session.execute(delete(model).where(col.in_(user_ids)))

    # Messages tied to demo groups / conversations
    group_ids = (
        await session.execute(
            select(GroupMember.group_id).where(GroupMember.user_id.in_(user_ids))
        )
    ).scalars().all()
    if group_ids:
        msg_ids = (
            await session.execute(
                select(ChatMessage.id).where(ChatMessage.group_id.in_(group_ids))
            )
        ).scalars().all()
        if msg_ids:
            await session.execute(
                delete(ChatMessageReaction).where(
                    ChatMessageReaction.message_id.in_(msg_ids)
                )
            )
        await session.execute(
            delete(ChatMessage).where(ChatMessage.group_id.in_(group_ids))
        )
        await session.execute(delete(GroupDay).where(GroupDay.group_id.in_(group_ids)))
        await session.execute(
            delete(HabitReport).where(HabitReport.group_id.in_(group_ids))
        )
        await session.execute(
            delete(GroupMember).where(GroupMember.group_id.in_(group_ids))
        )
        await session.execute(delete(Group).where(Group.id.in_(group_ids)))

    dm_ids = (
        await session.execute(
            select(DirectMessage.id).where(
                DirectMessage.sender_user_id.in_(user_ids)
                | DirectMessage.recipient_user_id.in_(user_ids)
            )
        )
    ).scalars().all()
    if dm_ids:
        await session.execute(
            delete(DirectMessageReaction).where(
                DirectMessageReaction.message_id.in_(dm_ids)
            )
        )
        await session.execute(delete(DirectMessage).where(DirectMessage.id.in_(dm_ids)))

    await session.execute(
        delete(Friendship).where(
            Friendship.user_low_id.in_(user_ids)
            | Friendship.user_high_id.in_(user_ids)
        )
    )
    await session.execute(delete(User).where(User.id.in_(user_ids)))
    await session.flush()
    return len(users)


def _onboarding(skill: bool = False) -> dict:
    if not skill:
        return {}
    return {
        "goal": "betterMorning",
        "goals": ["betterMorning"],
        "selected_skill_id": SKILL_ID,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "preferred_action_window": "morning",
    }


async def _ensure_favorite(session, user_id: str, skill_id: str) -> None:
    existing = await session.scalar(
        select(UserSkillFavorite.id).where(
            UserSkillFavorite.user_id == user_id,
            UserSkillFavorite.skill_id == skill_id,
        )
    )
    if existing is None:
        session.add(UserSkillFavorite(user_id=user_id, skill_id=skill_id))


async def _seed_empty(session) -> User:
    spec = ACCOUNTS["empty"]
    return await _upsert_user(
        session,
        email=spec["email"],
        nickname=spec["nickname"],
        name=spec["name"],
        about=spec["about"],
        avatar_key=spec["avatar"],
        profile_completed=False,
    )


async def _seed_matching(session) -> User:
    spec = ACCOUNTS["matching"]
    user = await _upsert_user(
        session,
        email=spec["email"],
        nickname=spec["nickname"],
        name=spec["name"],
        about=spec["about"],
        avatar_key=spec["avatar"],
        profile_completed=True,
        onboarding=_onboarding(skill=True),
        region_code=REGION,
        city="Москва",
        age=29,
    )
    await _ensure_favorite(session, user.id, SKILL_ID)

    entry = await session.scalar(
        select(WaitingRoomEntry).where(
            WaitingRoomEntry.user_id == user.id,
            WaitingRoomEntry.skill_id == SKILL_ID,
        )
    )
    expansion_at = datetime.now(timezone.utc) - timedelta(hours=2)
    if entry is None:
        session.add(
            WaitingRoomEntry(
                user_id=user.id,
                skill_id=SKILL_ID,
                region_code=REGION,
                allow_other_regions=True,
                expansion_offered_at=expansion_at,
            )
        )
    else:
        entry.allow_other_regions = True
        entry.expansion_offered_at = expansion_at
        entry.region_code = REGION
        session.add(entry)

    for idx, (email, nick, name) in enumerate(WAITING_PEERS):
        peer = await _upsert_user(
            session,
            email=email,
            nickname=nick,
            name=name,
            about="В очереди на утренний фокус.",
            avatar_key=f"a{(idx % 5) + 1}",
            profile_completed=True,
            onboarding=_onboarding(skill=True),
            region_code=REGION,
            city="Москва",
            age=26 + idx,
        )
        peer_entry = await session.scalar(
            select(WaitingRoomEntry).where(
                WaitingRoomEntry.user_id == peer.id,
                WaitingRoomEntry.skill_id == SKILL_ID,
            )
        )
        if peer_entry is None:
            session.add(
                WaitingRoomEntry(
                    user_id=peer.id,
                    skill_id=SKILL_ID,
                    region_code=REGION,
                    allow_other_regions=idx % 2 == 0,
                )
            )

    friend_email, friend_nick, friend_name, friend_avatar = INVITED_FRIEND
    friend = await _upsert_user(
        session,
        email=friend_email,
        nickname=friend_nick,
        name=friend_name,
        about="Друг из matching-сценария.",
        avatar_key=friend_avatar,
        profile_completed=True,
        region_code=REGION,
        city="Москва",
        age=27,
    )

    existing_req = await session.scalar(
        select(FriendRequest.id).where(
            FriendRequest.requester_user_id == user.id,
            FriendRequest.addressee_user_id == friend.id,
        )
    )
    if existing_req is None:
        session.add(
            FriendRequest(
                requester_user_id=user.id,
                addressee_user_id=friend.id,
                status="pending",
            )
        )

    notif = await session.scalar(
        select(Notification.id).where(
            Notification.user_id == user.id,
            Notification.type == "matching",
        )
    )
    if notif is None:
        session.add(
            Notification(
                user_id=user.id,
                type="matching",
                title="Ищем команду",
                body="Нашли 3 из 6 участников в вашем регионе. Можно расширить поиск.",
                payload=json.dumps({"skill_id": SKILL_ID, "found": 3, "needed": 6}),
            )
        )
    return user


def _team_day_pattern(day: date, *, cycle_start: date) -> str:
    """Return 'complete', 'partial', 'hero_miss', or 'off' for a calendar day."""
    if day < cycle_start - timedelta(days=30):
        return "off"
    if day < cycle_start:
        # Prior cycle — mostly complete
        if day.weekday() == 6:
            return "partial"
        return "complete"
    offset = (day - cycle_start).days
    if offset < 0:
        return "off"
    # Current cycle (day 0 = cycle start, day 21 = today when cycle_start = today-21)
    partial_days = {4, 11, 18}
    miss_days = {8, 15}
    if offset in miss_days:
        return "hero_miss"
    if offset in partial_days:
        return "partial"
    if offset > 21:
        return "off"
    return "complete"


async def _ensure_report(
    session,
    *,
    group_id: str,
    user_id: str,
    day: date,
    content: str = "Готово",
) -> None:
    existing = await session.scalar(
        select(HabitReport.id).where(
            HabitReport.group_id == group_id,
            HabitReport.user_id == user_id,
            HabitReport.report_date == day,
        )
    )
    if existing is not None:
        return
    session.add(
        HabitReport(
            group_id=group_id,
            user_id=user_id,
            report_date=day,
            content_text=content,
            status="ready",
        )
    )


async def _recompute_history(
    session,
    group: Group,
    members: list[User],
    *,
    cycle_start: date,
    today: date,
) -> None:
    hero = members[0]
    start = cycle_start - timedelta(days=30)
    d = start
    while d <= today:
        pattern = _team_day_pattern(d, cycle_start=cycle_start)
        if pattern == "off":
            d += timedelta(days=1)
            continue
        if pattern != "hero_miss":
            await _ensure_report(
                session,
                group_id=group.id,
                user_id=hero.id,
                day=d,
                content=f"Утро {d.isoformat()}",
            )
        if pattern == "complete":
            for member in members:
                await _ensure_report(
                    session,
                    group_id=group.id,
                    user_id=member.id,
                    day=d,
                )
        elif pattern == "partial":
            for member in members[:4]:
                await _ensure_report(
                    session,
                    group_id=group.id,
                    user_id=member.id,
                    day=d,
                )
        await recompute_group_day(session, group, d)
        if pattern == "complete":
            await award_team_day_primes(session, group, d)
        d += timedelta(days=1)


async def _seed_filled(session) -> User:
    spec = ACCOUNTS["filled"]
    today = date.today()
    cycle_start = today - timedelta(days=21)

    hero = await _upsert_user(
        session,
        email=spec["email"],
        nickname=spec["nickname"],
        name=spec["name"],
        about=spec["about"],
        avatar_key=spec["avatar"],
        profile_completed=True,
        onboarding=_onboarding(skill=True),
        region_code=REGION,
        city="Москва",
        age=31,
    )
    await _ensure_favorite(session, hero.id, SKILL_ID)

    teammates: list[User] = []
    for email, nick, name, avatar in TEAMMATES:
        teammates.append(
            await _upsert_user(
                session,
                email=email,
                nickname=nick,
                name=name,
                about=f"Участник команды · {name}",
                avatar_key=avatar,
                profile_completed=True,
                onboarding=_onboarding(skill=True),
                region_code=REGION,
                city="Москва",
                age=28,
            )
        )
    all_members = [hero, *teammates]

    group = await session.scalar(
        select(Group).where(
            Group.skill_id == SKILL_ID,
            Group.region_code == REGION,
            Group.name == "Demo Morning Focus",
        )
    )
    if group is None:
        group = Group(
            name="Demo Morning Focus",
            skill_id=SKILL_ID,
            region_code=REGION,
            status="active",
            max_members=6,
        )
        session.add(group)
        await session.flush()
    else:
        group.status = "active"
        session.add(group)

    for user in all_members:
        membership = await session.scalar(
            select(GroupMember).where(
                GroupMember.group_id == group.id,
                GroupMember.user_id == user.id,
            )
        )
        if membership is None:
            session.add(
                GroupMember(
                    group_id=group.id,
                    user_id=user.id,
                    role="member",
                    confirmed_participation=True,
                    accepted_rules=True,
                    active=True,
                )
            )
        else:
            membership.active = True
            membership.confirmed_participation = True
            membership.accepted_rules = True
            session.add(membership)

    await _recompute_history(
        session, group, all_members, cycle_start=cycle_start, today=today
    )

    for user in all_members:
        membership = await session.scalar(
            select(GroupMember).where(
                GroupMember.group_id == group.id,
                GroupMember.user_id == user.id,
            )
        )
        assert membership is not None
        await sync_group_member_streak(
            session, membership, group_id=group.id, user_id=user.id, today=today
        )
        await _sync_user_daily_progress(session, user)

    # Team chat
    if not await session.scalar(
        select(ChatMessage.id).where(ChatMessage.group_id == group.id)
    ):
        msgs = [
            (teammates[0].id, "m.text", "Доброе утро! Кто уже сделал фокус-блок?"),
            (teammates[1].id, "m.text", "Я закончила — 25 минут без телефона ✅"),
            (hero.id, "m.text", "Отлично! Сегодня держим темп, осталось 8 дней цикла."),
            (
                teammates[2].id,
                "prime.system",
                "🎉 День закрыт всей командой — +1 Прайм каждому",
            ),
        ]
        message_ids: list[str] = []
        for sender_id, msgtype, body in msgs:
            msg = ChatMessage(
                group_id=group.id,
                sender_user_id=sender_id,
                sender_matrix_id="",
                event_id=f"demo-{uuid4()}",
                msgtype=msgtype,
                body=body,
            )
            session.add(msg)
            await session.flush()
            message_ids.append(msg.id)
        session.add(
            ChatMessageReaction(
                message_id=message_ids[0],
                user_id=hero.id,
                emoji="🔥",
            )
        )
        session.add(
            ChatMessageReaction(
                message_id=message_ids[1],
                user_id=teammates[0].id,
                emoji="💪",
            )
        )

    # Direct chat with invited friend (accepted)
    friend_email, friend_nick, friend_name, friend_avatar = INVITED_FRIEND
    friend = await _upsert_user(
        session,
        email=friend_email,
        nickname=friend_nick,
        name=friend_name,
        about="Подруга Марии · утренний фокус",
        avatar_key=friend_avatar,
        profile_completed=True,
        region_code=REGION,
        city="Москва",
        age=27,
    )
    low, high = _friendship_pair(hero.id, friend.id)
    if not await session.scalar(
        select(Friendship.id).where(
            Friendship.user_low_id == low,
            Friendship.user_high_id == high,
        )
    ):
        session.add(Friendship(user_low_id=low, user_high_id=high))

    conv_key = _direct_conversation_key(hero.id, friend.id)
    if not await session.scalar(
        select(DirectMessage.id).where(DirectMessage.conversation_key == conv_key)
    ):
        invite = DirectMessage(
            conversation_key=conv_key,
            sender_user_id=friend.id,
            recipient_user_id=hero.id,
            msgtype="prime.invite",
            body="Присоединяйся к утреннему фокусу — у нас отличная команда!",
        )
        session.add(invite)
        await session.flush()
        reply = DirectMessage(
            conversation_key=conv_key,
            sender_user_id=hero.id,
            recipient_user_id=friend.id,
            msgtype="m.text",
            body="Спасибо! Уже в команде, давай синхронизироваться завтра утром.",
            reply_to_id=invite.id,
        )
        session.add(reply)
        await session.flush()
        session.add(
            DirectMessageReaction(
                message_id=reply.id,
                user_id=friend.id,
                emoji="❤️",
            )
        )
        session.add(
            DirectConversationRead(
                user_id=hero.id,
                friend_id=friend.id,
                last_read_at=datetime.now(timezone.utc),
            )
        )

    if not await session.scalar(
        select(Notification.id).where(
            Notification.user_id == hero.id,
            Notification.type == "team_day",
        )
    ):
        session.add(
            Notification(
                user_id=hero.id,
                type="team_day",
                title="День закрыт",
                body="Команда закрыла вчерашний день — +1 Прайм",
                payload=json.dumps({"group_id": group.id}),
            )
        )

    return hero


async def run_seed(*, reset: bool) -> None:
    async with SessionLocal() as session:
        if reset:
            removed = await _delete_demo_users(session)
            await session.commit()
            print(f"Reset: removed {removed} demo user(s).")

        empty = await _seed_empty(session)
        matching = await _seed_matching(session)
        filled = await _seed_filled(session)
        await session.commit()

    print("\nDemo scenarios ready (password for all: DemoPrime123!)\n")
    print("EMPTY — onboarding / zero states")
    print(f"  email:    {empty.email}")
    print(f"  nickname: @{empty.nickname}")
    print("")
    print("MATCHING — waiting room, 3/6 found, invited friend")
    print(f"  email:    {matching.email}")
    print(f"  nickname: @{matching.nickname}")
    print("")
    print("FILLED — primary gate account (day 22/30, team of 6)")
    print(f"  email:    {filled.email}")
    print(f"  nickname: @{filled.nickname}")
    print("")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed PRIME demo visual-gate scenarios")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Confirm seeding (required)",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete existing @prime.local demo users first",
    )
    args = parser.parse_args()
    _assert_safe_to_run(args.yes)
    asyncio.run(run_seed(reset=args.reset))


if __name__ == "__main__":
    main()
