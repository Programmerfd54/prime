# Backend gaps — не фейкать на клиенте

Источник в коде: [`prime-flutter/lib/core/network/backend_gaps.dart`](../../prime-flutter/lib/core/network/backend_gaps.dart).

Если функции нет на API — готовим абстракцию/контракт на клиенте и помечаем здесь.  
**Запрещено:** локальные фейковые сообщения, hardcoded users, имитация delivery/read без сервера.

## Уже закрыто на backend (этот оверхол)

| Возможность | Статус | Где |
|-------------|--------|-----|
| Progressive profile (about optional at setup) | done | `UpdateUserRequest` — about не обязателен; ≥50 слов при join waiting room |
| CORS для Flutter web (случайный порт) | done | `CORS_ALLOW_ORIGIN_REGEX` в `.env` / `main.py` |
| Email не в публичном payload | done | `_user_payload` без email |
| Confirm participation | done | `/groups/{id}/intro/continue` (+ alias) |
| Waiting room multi-queue per skill | done | несколько `WaitingRoomEntry` |
| REST chat history (group + DM) | done | poll-based |
| X-Request-ID correlation | done | middleware + CORS `expose_headers` |
| DM inbox last message / unread | done | `GET /direct-chats`, `POST /direct-chats/{id}/read`, `DirectConversationRead` |
| Password reset | done | `POST /auth/forgot-password`, `POST /auth/reset-password` (+ local expose token) |
| Cancel outgoing friend request | done | `DELETE /friends/requests/{id}` + pending_direction in by-nickname |

## Требуется backend (клиент не имитирует)

| Gap | Зачем продукту | Предлагаемый контракт | Клиент сейчас |
|-----|----------------|----------------------|---------------|
| WebSocket / SSE chat | realtime без polling | `WS /api/v1/realtime` events: `dm.message`, `group.message`, `waiting_room.updated` | HTTP poll 3s/10s |
| Refresh token | безопасная сессия | `POST /auth/refresh`, revoke | только access JWT; на 401 → logout |
| Nickname availability | debounce без 404-хака | `GET /users/nickname-available?nick=` | `by-nickname` 404 = free |
| Push (FCM/APNs) | team ready / messages в фоне | register device + send | local prefs toggle only |
| Delivery / read receipts | статусы в чате | поля `delivered_at` / `read_at` | только sending/sent/failed |
| Email verify | подтверждение почты | `/auth/verify` | нет |
| Block / report user | безопасность | `/users/{id}/block`, `/reports/abuse` | нет UI-API |
| Delete account | GDPR / settings | `DELETE /users/me` | нет |
| Logout all devices | безопасность | revoke all refresh/access | нет |
| Custom habits CRUD | «накопи 10 Праймов» | CRUD skills | флаг `can_create_custom_skills` без API |
| Real voting | конец цикла | реальное голосование | stub `accepted: true` |
| DM media | паритет с group chat | upload + send | только text |

## Правило для Stage 2–4

1. Если gap блокирует UX — показать честное empty/disabled состояние + короткий текст «скоро» **только** если нет рабочего пути.
2. Предпочтительнее рабочий путь на существующих API (polling, soft gate about).
3. Новые repository-интерфейсы под будущий WS/refresh класть рядом с реальной poll/JWT реализацией, без parallel fake UI.
