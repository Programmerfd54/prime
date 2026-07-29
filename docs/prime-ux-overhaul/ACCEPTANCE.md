# Приёмка продукта PRIME (UX overhaul)

Обновлено после прохождения Stage 1–4.

## Blocker / Critical

- [x] Новые DM появляются без ручного refresh (poll)
- [x] Group chat на общем `ChatSyncController`
- [x] Ошибки API нормализованы (FailureMapper)
- [x] 429 учитывает Retry-After в тексте
- [x] Формы не очищаются после сетевой ошибки
- [x] Mid-session 401 → login
- [x] Offline / connection banner
- [x] Waiting room auto-update + Groups badge
- [x] Progressive profile + about quality gate
- [x] Email не в публичном профиле API
- [x] CORS для Flutter web
- [x] `flutter analyze` без errors
- [x] Unit/widget tests green

## Activation UX

- [x] Онбординг: ценность + skip + back + replay
- [x] Регистрация: debounce, password UX, 409 → login
- [x] Home next-step / day states
- [x] CTA «Найти команду»
- [x] Matchmaking slots / prep / pre-search / confirm copy
- [x] Friend search states + «Написать»
- [x] DM: dates, load older, header→profile
- [x] Inbox last message / unread (`GET /direct-chats`)
- [x] Password reset (`/auth/forgot-password`, `/auth/reset-password`)
- [x] Cancel outgoing friend request
- [x] Chats tab as primary inbox surface
- [!] Delete account / email verify / block-report — backend gap
- [x] Correlation ID (`X-Request-ID`) + copy в error UI

## Design system

- [x] Tokens + typography
- [x] Core components wired to real screens
- [x] AsyncErrorView / StatCard / PrimeHeader wrappers
- [~] Некоторые legacy hex на старых визуалах (не блокер)

## Команды финального прогона

```bash
cd prime-backend && python3 -m pytest
cd prime-flutter && flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Ручной сценарий: два профиля → DM без refresh → soft profile → habit → find team → очередь auto-update.
