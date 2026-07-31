"""In-process push fan-out for live direct-message delivery over SSE."""

from __future__ import annotations

import asyncio
import json
import logging
import os
from dataclasses import asdict, dataclass
from typing import Any, Union
from uuid import uuid4

from .config import get_settings
from .redis_client import create_redis_pubsub_client, get_redis


logger = logging.getLogger("prime.realtime")
REDIS_CHANNEL = "prime:sse:v1"
PROCESS_ID = f"{os.getpid()}:{uuid4().hex}"


@dataclass(frozen=True)
class DirectMessagePush:
    friend_id: str
    message_id: str
    message: dict[str, Any] | None = None


@dataclass(frozen=True)
class DirectChatReadPush:
    """Peer opened the chat and read messages up to [read_at]."""

    friend_id: str
    read_at: str


@dataclass(frozen=True)
class NotificationPush:
    """In-app notification for SSE delivery."""

    notification: dict[str, Any]


@dataclass(frozen=True)
class WaitingRoomUpdatePush:
    """Waiting-room queue changed (e.g. pair invite accepted)."""

    skill_id: str
    revision: int = 0
    reason: str = "updated"


@dataclass(frozen=True)
class GroupUpdatePush:
    """Group membership or intro confirmation changed."""

    group_id: str
    revision: int = 0
    phase: str = ""
    reason: str = "updated"
    milestone_id: str | None = None


@dataclass(frozen=True)
class GroupChatUpdatePush:
    """New message in a group chat (including prep-phase)."""

    group_id: str


@dataclass(frozen=True)
class SessionRevokedPush:
    """Close matching live streams immediately after logout/revocation."""

    session_id: str


RealtimePush = Union[
    DirectMessagePush,
    DirectChatReadPush,
    NotificationPush,
    WaitingRoomUpdatePush,
    GroupUpdatePush,
    GroupChatUpdatePush,
    SessionRevokedPush,
]


class DirectMessageEventHub:
    def __init__(self) -> None:
        self._queues: dict[str, list[asyncio.Queue[RealtimePush]]] = {}
        self._redis_task: asyncio.Task | None = None

    def subscribe(self, user_id: str) -> asyncio.Queue[RealtimePush]:
        queue: asyncio.Queue[RealtimePush] = asyncio.Queue(maxsize=64)
        self._queues.setdefault(user_id, []).append(queue)
        self._ensure_redis_listener()
        return queue

    @property
    def active_connections(self) -> int:
        return sum(len(queues) for queues in self._queues.values())

    @property
    def subscribed_users(self) -> int:
        return len(self._queues)

    @property
    def queued_events(self) -> int:
        return sum(
            queue.qsize()
            for queues in self._queues.values()
            for queue in queues
        )

    def unsubscribe(self, user_id: str, queue: asyncio.Queue[RealtimePush]) -> None:
        queues = self._queues.get(user_id)
        if not queues:
            return
        if queue in queues:
            queues.remove(queue)
        if not queues:
            self._queues.pop(user_id, None)

    def publish(self, recipient_user_id: str, push: DirectMessagePush) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_read(self, recipient_user_id: str, push: DirectChatReadPush) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_notification(self, recipient_user_id: str, push: NotificationPush) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_waiting_room_update(
        self,
        recipient_user_id: str,
        push: WaitingRoomUpdatePush,
    ) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_group_update(
        self,
        recipient_user_id: str,
        push: GroupUpdatePush,
    ) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_group_chat_update(
        self,
        recipient_user_id: str,
        push: GroupChatUpdatePush,
    ) -> None:
        self._enqueue(recipient_user_id, push)

    def publish_session_revoked(
        self,
        recipient_user_id: str,
        push: SessionRevokedPush,
    ) -> None:
        self._enqueue(recipient_user_id, push)

    def _enqueue(
        self,
        recipient_user_id: str,
        push: RealtimePush,
        *,
        broadcast: bool = True,
    ) -> None:
        for queue in self._queues.get(recipient_user_id, []):
            try:
                queue.put_nowait(push)
            except asyncio.QueueFull:
                # Drop oldest and retry once — better late than never blocking send.
                try:
                    queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
                try:
                    queue.put_nowait(push)
                except asyncio.QueueFull:
                    pass
        if broadcast and get_settings().redis_url:
            asyncio.create_task(self._broadcast(recipient_user_id, push))

    def _ensure_redis_listener(self) -> None:
        if not get_settings().redis_url:
            return
        if self._redis_task is None or self._redis_task.done():
            self._redis_task = asyncio.create_task(self._redis_listener())

    async def _broadcast(self, recipient_user_id: str, push: RealtimePush) -> None:
        redis = await get_redis()
        if redis is None:
            return
        event = {
            "origin": PROCESS_ID,
            "recipient_user_id": recipient_user_id,
            "kind": type(push).__name__,
            "payload": asdict(push),
        }
        try:
            await redis.publish(REDIS_CHANNEL, json.dumps(event, ensure_ascii=False))
        except Exception:
            logger.warning("sse_redis_publish_failed", exc_info=True)

    async def _redis_listener(self) -> None:
        push_types = {
            item.__name__: item
            for item in (
                DirectMessagePush,
                DirectChatReadPush,
                NotificationPush,
                WaitingRoomUpdatePush,
                GroupUpdatePush,
                GroupChatUpdatePush,
                SessionRevokedPush,
            )
        }
        retry_delay = 1.0
        while True:
            redis = await create_redis_pubsub_client()
            if redis is None:
                await asyncio.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 30.0)
                continue
            pubsub = None
            try:
                pubsub = redis.pubsub(ignore_subscribe_messages=True)
                await pubsub.subscribe(REDIS_CHANNEL)
                retry_delay = 1.0
                async for message in pubsub.listen():
                    raw = message.get("data")
                    if not isinstance(raw, str):
                        continue
                    event = json.loads(raw)
                    if event.get("origin") == PROCESS_ID:
                        continue
                    cls = push_types.get(str(event.get("kind") or ""))
                    recipient = str(event.get("recipient_user_id") or "")
                    payload = event.get("payload")
                    if cls is None or not recipient or not isinstance(payload, dict):
                        continue
                    self._enqueue(recipient, cls(**payload), broadcast=False)
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                # Redis may be restarted independently of the API. Reconnect
                # with bounded backoff and avoid multi-kilobyte tracebacks on
                # every failed attempt.
                logger.warning(
                    "sse_redis_listener_reconnecting",
                    extra={"error_type": type(exc).__name__, "retry_seconds": retry_delay},
                )
                await asyncio.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 30.0)
            finally:
                if pubsub is not None:
                    try:
                        await pubsub.aclose()
                    except Exception:
                        pass
                try:
                    await redis.aclose()
                except Exception:
                    pass

    async def close(self) -> None:
        task = self._redis_task
        self._redis_task = None
        if task is not None:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)


direct_message_hub = DirectMessageEventHub()


async def close_direct_message_hub() -> None:
    await direct_message_hub.close()

__all__ = [
    "DirectChatReadPush",
    "DirectMessagePush",
    "DirectMessageEventHub",
    "GroupChatUpdatePush",
    "GroupUpdatePush",
    "NotificationPush",
    "SessionRevokedPush",
    "RealtimePush",
    "WaitingRoomUpdatePush",
    "direct_message_hub",
    "close_direct_message_hub",
]
