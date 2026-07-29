# Stage 2 — Activation UX

**Status:** done  
**Depends on:** Stage 1  
**Out of scope:** полный набор DS-компонентов (Stage 3), integration/golden suite (Stage 4), WebSocket

## Цель

Цельный путь активации без противоречий CTA/терминов:

```text
Онбординг → регистрация → soft profile → привычка → поиск команды
→ confirm → цикл → отчёт → друзья/чаты → профиль
```

**Правило:** использовать уже созданные `lib/ui/components/*`, `lib/ui/states/*`, `lib/design/tokens.dart`, `AppCopy`. Не плодить параллельные кнопки/поля.

## 2.1 Онбординг — `onboarding_screen.dart`

- [x] 3 экрана ценности (проблема/результат; как работает; зачем группа)
- [x] Skip + progress dots
- [x] `finishOnboarding` / не форсить после re-login
- [x] Replay из settings (`replayOnboarding`)
- [x] Analytics view/next/complete/skip
- [x] Убрать остаточный «атмосферный» шум / сверить копирайт на 100% со спекой
- [x] Кнопка «назад» между страницами (доступная навигация)

**Приёмка:** после skip/complete пользователь понимает ежедневное действие, 30 дней, роль группы.

## 2.2 Регистрация / вход — `auth_screen.dart`

- [x] Register primary / login secondary
- [x] Show/hide password + requirements до submit
- [x] Без confirm password
- [x] Nickname debounce через `by-nickname`
- [x] AutofillGroup
- [x] Agreement links (terms/privacy)
- [x] FailureMapper; поля не очищаются при ошибке
- [x] CTA disabled пока обязательные условия не выполнены (проверить edge cases)
- [x] 409 email → явный оффер «Войти» (сейчас общий conflict text)
- [x] Восстановление пароля — `POST /auth/forgot-password` + `POST /auth/reset-password`

**Приёмка:** регистрация → soft profile без потери данных при offline/500.

## 2.3 Progressive profile — `profile_setup_screen.dart`

- [x] Обязательно: имя, ник, область, возраст
- [x] About optional + helper (кто видит / можно позже)
- [x] CTA «Продолжить»
- [x] RU labels
- [x] Soft gate ≥50 слов перед join (skills detail sheet)
- [x] Чипы/короткие вопросы → сбор about перед join (улучшить качество текста)
- [x] Валидация «мусорного» about на soft gate (точка / повтор слов)
- [x] Единый source of truth после save: `AuthProvider.refreshUser` везде после правок имени

**Приёмка:** можно войти в app без about; нельзя стартовать поиск без осмысленного about.

## 2.4 Главный экран — `dashboard_screen.dart`

- [x] Next-step card (new / searching / matched / active)
- [x] Календарь вторичен (скрыт без истории)
- [x] Zero metrics hint вместо голых нулей
- [x] CTA «Выбрать привычку» → tab Habits
- [x] Friend search: not found ≠ server error; «Написать» если друзья
- [x] Active day / day-done состояния (отчёт сегодня / успех дня) — усилить
- [x] Friends block не доминирует у new user (проверить порядок секций)
- [x] Empty chats CTA «Найти друга» (AppEmptyState)
- [x] Inbox preview last message + unread (`GET /direct-chats`)

**Приёмка:** new user видит один главный следующий шаг, не календарь.

## 2.5 Привычки — `skills_screen.dart`

- [x] `AppHabitCard` + CTA «Найти команду»
- [x] Soft about gate перед join
- [x] Analytics habit list/details/search
- [x] Detail: ежедневное действие, что считается done, отчёт, пропуск, роль команды
- [x] Multi-queue copy: «первая собранная команда; остальные поиски можно остановить»
- [x] Карточка: время / сложность / время дня (если нет в API — честно не выдумывать поля; вынести из description)
- [x] Custom habit card: не обещать создание без API (disabled + «нужно 10 Праймов» / скоро)

**Приёмка:** пользователь не жмёт поиск, не понимая обязательства 30 дней.

## 2.6 Группы / матчмейкинг — `groups_screen.dart`, `group_detail_screen.dart`

- [x] Poller sync + stop/expand
- [x] Empty → указание на Привычки / find team
- [x] Confirm participation / rules flow существует
- [x] Слоты: ваш слот + найденные + пустые + этап + время до expand
- [x] Prep step во время ожидания (заполнить about / понять отчёт)
- [x] Pre-search summary sheet: обязательство, регион, отмена
- [x] Badge на вкладке Groups при matched (если возможно без push)
- [x] Copy confirm: «Команда готова. Подтвердите участие»

**Приёмка:** нет ложной активности; статус очереди понятен без refresh.

## 2.7 Профиль — `profile_screen.dart`, `account_settings_screen.dart`

- [x] Метрики: Праймы / Дней подряд / Успешных дней
- [x] Email не в hero; в settings
- [x] Logout note / settings entry
- [x] Achievements sort (near-term first)
- [x] Empty achievements copy для new user
- [x] Иерархия: личность → прогресс → привычка → цель → achievements
- [x] Объяснение механики Праймов (короткий info)
- [x] Вынести logout полностью в settings (убрать конкурирующий CTA с профиля, если ещё есть)
- [x] Edit public profile отдельным экраном/секцией
- [x] Block/report/delete account — только если API (иначе честный gap)

**Приёмка:** метрики и настройки без ложных CTA.

## 2.8 Друзья и чаты

- [x] DM poll + optimistic send states
- [x] Search states: found / not found / error / friend → write
- [x] Self / pending incoming (accept из bell) — проверить UX связности
- [x] Cancel outgoing request (`DELETE /friends/requests/{id}`)
- [x] Chat header → public profile + menu
- [x] Date separators Сегодня/Вчера в DM
- [x] Pagination older DM через `ChatSyncController.loadOlder` в UI
- [x] Список чатов как primary surface — вкладка «Чаты» в `MainShell`

## Затронутые файлы (ожидаемо)

- `prime-flutter/lib/screens/onboarding_screen.dart`
- `prime-flutter/lib/screens/auth_screen.dart`
- `prime-flutter/lib/screens/forgot_password_screen.dart`
- `prime-flutter/lib/screens/reset_password_screen.dart`
- `prime-flutter/lib/screens/profile_setup_screen.dart`
- `prime-flutter/lib/screens/dashboard_screen.dart`
- `prime-flutter/lib/screens/skills_screen.dart`
- `prime-flutter/lib/screens/groups_screen.dart`
- `prime-flutter/lib/screens/group_detail_screen.dart`
- `prime-flutter/lib/screens/profile_screen.dart`
- `prime-flutter/lib/screens/account_settings_screen.dart`
- `prime-flutter/lib/screens/direct_chat_screen.dart`
- `prime-flutter/lib/screens/chats_screen.dart`
- `prime-flutter/lib/screens/main_shell.dart`
- `prime-flutter/lib/l10n/copy.dart`
- Переиспользуем: `lib/ui/components/*`, `lib/ui/states/*`

## Критерии приёмки Stage 2

1. Сквозной путь new user до «поиск команды» без тупиков и ложных CTA.
2. Один главный CTA на ключевых экранах.
3. Термины согласованы (нет навык/челлендж в user-facing copy без нужды).
4. Друг → «Написать» из результата поиска.
5. `flutter analyze` + существующие tests green.
6. Статусы в этом файле обновлены после итерации.

## Команды

```bash
cd prime-backend && python3 -m pytest
cd prime-flutter && flutter analyze && flutter test
# Manual: register → profile (skip about) → habit detail → soft about → find team → home next-step
# Manual: login → forgot password → reset → chats tab
```

После закрытия Stage 2 → перейти к [03-design-system.md](./03-design-system.md).
