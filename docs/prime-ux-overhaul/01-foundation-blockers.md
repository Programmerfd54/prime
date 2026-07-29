# Stage 1 — Foundation & blockers

**Status:** done  
**Depends on:** local Docker Postgres + API  
**Out of scope:** полный redesign экранов (Stage 2–3), WebSocket backend

## Цель

Стабильный сетевой слой, ошибки, polling чатов/очереди, progressive profile, CORS для web.

## Чеклист

### Errors & session

- [x] `AppFailure` + типы (Validation / Unauthorized / …)
- [x] `FailureMapper` из Dio (400–504, network, timeout)
- [x] Пользовательские тексты в `AppCopy` / mapper
- [x] Dio interceptor → mid-session 401 → `AuthProvider.handleUnauthorized`
- [x] `ApiClient.errorMessage` делегирует в mapper
- [x] Retry-After UX для 429 (текст с секундами)
- [x] Global error boundary (`installAppErrorBoundary` / `ErrorWidget`) + correlation ID copy в UI
- [x] Backend `X-Request-ID` + CORS `expose_headers`

### Offline / loading states

- [x] `AppConnectionBanner`, `AppLoadingState`, `AppErrorState`, `AppEmptyState`
- [x] Offline mode banner в shell при cached session
- [x] Ключевые сетевые экраны используют states/DS

### Chat realtime (poll)

- [x] `ChatSyncController` + `MessageDedupe`
- [x] DM: poll, lifecycle, sending/sent/failed + retry
- [x] Group chat на `ChatSyncController`
- [x] Inbox list last-message / unread — `GET /direct-chats` + mark-read

### Waiting room

- [x] `WaitingRoomPoller` + live uncached GET
- [x] Lifecycle в `MainShell`
- [x] Snackbar «Команда готова» + badge на Groups

### Progressive profile / CORS

- [x] Backend about optional на setup; ≥50 на join
- [x] Soft gate + junk validation (`AboutQuality`)
- [x] `CORS_ALLOW_ORIGIN_REGEX` для Flutter web

### Analytics facade

- [x] Typed events + debug sink
- [x] Воронки onboarding/auth/habits/messages (расширено в Stage 4)

## Критерии приёмки Stage 1

1. Flutter web без CORS errors.
2. DM + group chat без ручного refresh (poll).
3. Очередь auto-update.
4. Setup без 50 слов; join с about quality gate.
5. `flutter analyze` + tests green.
6. Ошибки показывают/копируют correlation code при наличии `X-Request-ID`.
7. Home → личные чаты: last message + unread badge.

## Команды

```bash
cd prime-backend && python3 -m pytest
cd prime-flutter && flutter analyze && flutter test
```
