# 15 — Product upgrade v3

Статус: **done**

Полный продуктовый и дизайнерский апгрейд поверх visual v2: три приоритетных экрана (Главная, Привычки, Группы), живой поиск команды, realtime/push, чаты, остальные экраны, механики удержания и рост.

## Цель

Закрыть продуктовые дыры, видимые на скринах и в коде: пустые «темп/неделя», дубли featured-привычек, вертикальный стек очередей с двумя таймерами и расхождением «15 мин / 1 час», god-file `misc.py`, заглушка `/notifications`, нетипизированный чат.

## Сделано

### Backend split
- [x] `SKILLS` → `prime-backend/app/skills_catalog.py`
- [x] Роутеры: `catalog`, `social`, `waiting_room`, `groups`, `chat`, `reports`, `notifications`
- [x] Shared helpers → `group_service.py`
- [x] `misc.py` — facade для тестов / совместимости
- [x] Partial start: **24ч → 12ч** (`GROUP_PARTIAL_START_HOURS`)
- [x] Expansion copy: минуты из `REGION_EXPANSION_DELAY` (не «1 час»)

### Главная
- [x] `AppBentoMetrics`: день цикла X/30, до следующего Прайма, лучший день, сравнение с прошлой неделей
- [x] `PrimeWeeklyBars`: ghost-бары, baseline, легенда, tap-подсказка
- [x] Режим «одна задача» + празднование отчёта, recovery-поток

### Привычки
- [x] Убрано дублирование featured в каталоге
- [x] `HabitProgramCatalog` → реальная длительность / сложность / время дня
- [x] Фильтр по времени дня, сравнение программ
- [x] Деталь: таймлайн дня, кривая сложности, team ring, пробный день

### Группы + живой поиск
- [x] Вкладки «Мой цикл» / «Поиск», сегменты очередей вместо вертикального стека
- [x] Единая шкала `AppSearchTimeline` (12ч), онлайн по очереди
- [x] Stats: регион/навык, топ-регионов, медиана сборки, слоты, тикер, pair-invite
- [x] `User.last_seen_at`, `online_in_pool` в waiting-room payload

### Realtime / push
- [x] Таблицы `notifications`, `device_tokens`
- [x] Реальный `GET /notifications`, read, `POST /devices/register`
- [x] SSE `GET /events/stream`
- [x] Flutter `RealtimeClient` + polling fallback, центр уведомлений, match snackbar

### Чаты
- [x] Типизированная `ChatMessageModel` (DM)
- [x] Reply / реакции / quick replies / read ticks / карточка отчёта
- [x] Командный таб: список чатов + unread, pin «день X из 30», support→Prime, системные карточки

### Остальные экраны / онбординг
- [x] Профиль: путь достижений, цикл vs прошлый, шеринг
- [x] Публичный профиль: «Общее с вами», приглашение
- [x] Настройки: пресеты приватности, soft-delete аккаунта
- [x] История Праймов: график и разбор
- [x] Онбординг: пробный день до регистрации; email на шаге «найти команду»

### Механики / рост
- [x] Заморозка серии, ставка на цикл, недельный челлендж, recovery, окно ритуала, наставничество
- [x] Турниры + лидерборд в навигации, поиск друзей, кастомные привычки (10 Праймов) + инвайт-код, нативный шеринг

## QA

```bash
cd prime-flutter && flutter analyze && flutter test
cd prime-backend && python3 -m pytest -q
```

| Проверка | Результат |
|----------|-----------|
| Flutter analyze | без error (infos допустимы) |
| Flutter test | **130** passed (включая goldens / a11y inventory) |
| Backend pytest | **55** passed |

## Ключевые пути

| Область | Путь |
|---------|------|
| Skills catalog | `prime-backend/app/skills_catalog.py` |
| Routers | `prime-backend/app/routers/{groups,waiting_room,chat,reports,social,notifications,group_service}.py` |
| Home metrics | `prime-flutter/lib/ui/components/editorial/app_hero_module.dart` |
| Weekly bars | `prime-flutter/lib/design/visuals/charts/prime_weekly_bars.dart` |
| Habits catalog UI | `prime-flutter/lib/ui/components/editorial/app_habit_catalog.dart` |
| Skills screen | `prime-flutter/lib/screens/skills_screen.dart` |
| Groups / search | `prime-flutter/lib/screens/groups_screen.dart` |
| Team formation | `prime-flutter/lib/ui/components/editorial/app_team_formation.dart` |
| Realtime | `prime-flutter/lib/core/sync/realtime_client.dart` |
| Achievements | `prime-flutter/lib/ui/components/editorial/app_achievement_collection.dart` |

## Заметки

- Facade `misc.py` должен импортировать `notifications` из `notifications.py`, не из `social.py`.
- Hero достижений снова показывает «Ближайшая цель»; smoke-тест допускает дубль имени в hero + path.
