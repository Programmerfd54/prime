"""In-process push fan-out for live direct-message delivery over SSE."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any, Union


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


@dataclass(frozen=True)
class GroupUpdatePush:
    """Group membership or intro confirmation changed."""

    group_id: str


@dataclass(frozen=True)
class GroupChatUpdatePush:
    """New message in a group chat (including prep-phase)."""

    group_id: str


RealtimePush = Union[
    DirectMessagePush,
    DirectChatReadPush,
    NotificationPush,
    WaitingRoomUpdatePush,
    GroupUpdatePush,
    GroupChatUpdatePush,
]


class DirectMessageEventHub:
    def __init__(self) -> None:
        self._queues: dict[str, list[asyncio.Queue[RealtimePush]]] = {}

    def subscribe(self, user_id: str) -> asyncio.Queue[RealtimePush]:
        queue: asyncio.Queue[RealtimePush] = asyncio.Queue(maxsize=64)
        self._queues.setdefault(user_id, []).append(queue)
        return queue

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

    def _enqueue(self, recipient_user_id: str, push: RealtimePush) -> None:
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


direct_message_hub = DirectMessageEventHub()

__all__ = [
    "DirectChatReadPush",
    "DirectMessagePush",
    "DirectMessageEventHub",
    "GroupChatUpdatePush",
    "GroupUpdatePush",
    "NotificationPush",
    "RealtimePush",
    "WaitingRoomUpdatePush",
    "direct_message_hub",
]
