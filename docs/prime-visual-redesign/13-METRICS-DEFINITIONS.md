# PRIME — определения метрик (§17)

Канонический глоссарий для UI, API и аналитики.  
**Правило продукта:** не показывать метрику без источника данных; не выдумывать цифры.

Связанные документы: [12-PRODUCT-REDESIGN-ROADMAP.md](./12-PRODUCT-REDESIGN-ROADMAP.md), [11-E2E-QA-CHECKLIST.md](./11-E2E-QA-CHECKLIST.md).

---

## 1. Пользовательские метрики (аккаунт)

| UI (рус.) | API / модель | Определение | Как считается сейчас | Где в UI |
|-----------|--------------|-------------|----------------------|----------|
| **Праймы** | `User.prime_points` | Накопленные очки за засчитанные отчёты | `COUNT(HabitReport)` где `status = ready` для пользователя (`_sync_user_daily_progress`) | Home bento, Profile hero, Public profile, Prime history |
| **Успешные дни** | `User.successful_days` | Число календарных дней, в которые есть ≥1 готовый отчёт | `COUNT(DISTINCT report_date)` среди ready-отчётов | Home, Profile, Public profile, Achievements |
| **Серия** (подпись в UI) | `CalendarOut.current_streak` / hero `streak` | Дни подряд с ≥1 ready-отчётом | Consecutive calendar days (`metrics_engine.current_consecutive_streak`) | Home, Profile, `AppBentoMetrics` |
| **День цикла** | hero `cycleDay` | Прогресс в 30-дневном цикле | `User.successful_days`, отображение `N/30` в Profile hero | Profile hero |
| **Баланс Праймов** | `User.prime_points` | То же, что Праймы | Идентично `prime_points` | `PrimeHistoryScreen` header |

### Начисление Прайма за отчёт

| Событие | Backend | UI |
|---------|---------|-----|
| Первый переход отчёта за день в `ready` | +1 `PrimeEvent`, пересчёт `prime_points` / `successful_days` | Snackbar, обновление Home/Profile |
| Редактирование уже готового отчёта | Без нового `PrimeEvent` | «Отчёт обновлён» |
| Отчёт `not_ready` | Не засчитывается | День не отмечен |

**Источник:** `POST /reports` → `PrimeEvent(amount=1, reason="Ежедневный отчёт")` при `previous_status != ready` и `report_status == ready`.

**История:** `GET /users/me/prime-events` — список начислений (`amount`, `reason`, `created_at`, опционально `skill_id`, `group_id`).

### Пороги и разблокировки

| Условие | Эффект |
|---------|--------|
| `prime_points >= 10` | `User.can_create_custom_skills = true` |
| `successful_days >= N` | Achievement unlocked (`GET /achievements`, N = 30 / 90 / 365 / …) |

---

## 2. Метрики группы / привычки

| UI | API / модель | Определение | Как считается |
|----|--------------|-------------|---------------|
| **День N из 30** (активная привычка) | `GET /reports/calendar?group_id=` | Прогресс текущего 30-дневного цикла в группе | `COUNT(days WHERE completed)` в календаре группы, cap 30 (`dashboardChallengeDays`) |
| **Серия в группе** | `GroupMember.streak` | Текущая consecutive-серия ready-отчётов в группе | Пересчёт из дат (`sync_group_member_streak`) |
| **Лучшая серия** | `GroupMember.best_streak` / `best_streak` в calendar/all | MAX consecutive run | `best_consecutive_streak` |
| **Статус отчёта сегодня** | `member.report_status` | `ready` / `not_ready` / отсутствует | Отчёт за `date.today()` в группе |

**Календарь группы:** `GET /reports/calendar?group_id=` — все отчёты пользователя в группе; `tracking_start_date` = дата вступления в группу.

**Глобальный календарь:** `GET /reports/calendar/all` — агрегация по всем группам; один день = выполнен, если есть ≥1 ready-отчёт в любой группе.

---

## 3. Командный ритм (Team Pulse)

| UI | API | Определение |
|----|-----|-------------|
| **Командный ритм** | `group.team_pulse` | Сводка активности команды за сегодня |
| `completed_today / total_active` | `team_pulse.completed_today`, `total_active` | Число active-участников с `report_status == ready` / всего active |
| Статус | `team_pulse.status` | `calm` · `high` · `support` · `all_done` — эвристика по доле готовых отчётов |
| Сообщение | `team_pulse.message` | Человекочитаемый текст (RU), генерируется на backend |
| Check-in | `team_pulse.check_ins_today` | Сегодняшние `GroupCheckIn`: `done` · `starting` · `support` · `hard` |

**Источник:** `POST /groups/{id}/check-in`, payload группы в `GET /groups/{id}`.

### Recap недели (`team_recap`)

| Поле | Определение |
|------|-------------|
| `ready_reports` | Число `HabitReport` со `status=ready` за последние 7 дней (active-участники) |
| `pace_percent` | `ready_reports / (active_members × 7) × 100`, cap 100 |
| `best_day` / `best_day_count` | День с макс. числом уникальных участников с ready-отчётом |
| `support_signals` | `support_given` отчёты + check-in `support`/`hard` + реакции в чате |
| `message` | Сводка RU, генерируется на backend |

### Milestones команды (`team_milestones.items[]`)

| id | Условие unlock |
|----|----------------|
| `first_full_day` | В один день все active-участники отправили ready-отчёт |
| `week_together` | ≥ 7 календарных дней с ≥1 ready-отчётом команды |
| `hundred_actions` | ≥ 100 ready-отчётов команды (all-time) |
| `thirty_support` | ≥ 30 сигналов поддержки (all-time) |

**Источник:** embedded в `GET /groups/{id}` для статусов `active` · `rotating` · `voting` · `completed`.  
**UI:** `AppGroupRecapPanel`, `AppGroupMilestonesPanel`.

---

## 4. Отображение в UI (маппинг экранов)

| Экран | Компонент | Метрики |
|-------|-----------|---------|
| Home | `AppHomeGreeting`, `HomeNextStepCard`, `AppBentoMetrics` | Серия, Праймы, успешные дни; фаза дня из `HomeStateResolver` |
| Home | `ActiveChallengeCard` | N/30 по календарю группы |
| Home | `MonthlyReportCalendar` | Дни из `calendar/all` |
| Profile | `AppProfileHero` | Серия, Праймы, день цикла |
| Profile | `AppProfileGrowthSection` | Серия, успешные дни, Праймы; Insights из `calendar/all.insights` |
| Profile | `AppAchievementCollection` | Прогресс к порогам достижений |
| Profile | `PrimeHistoryScreen` | Баланс + `PrimeEvent` list |
| Public profile | `AppPublicProfileMetrics` | Праймы, успешные дни (с учётом `privacy_settings`) |
| Group detail | `AppGroupPulsePanel` | Team pulse + check-in |
| Group detail | `AppGroupRecapPanel`, `AppGroupMilestonesPanel` | Recap недели + milestones |

### Подписи в copy (`lib/l10n/copy.dart`)

| Ключ | Текст | Метрика |
|------|-------|---------|
| `AppCopy.primes` | Праймы | `prime_points` |
| `AppCopy.streak` | Дней подряд | *UI-лейбл; фактическое значение см. §5* |
| `AppCopy.cycleDays` | 30 дней | Длина цикла (константа продукта) |

---

## 5. Известные расхождения (техдолг)

| Тема | Статус |
|------|--------|
| **Consecutive streak** | ✅ `current_streak` / `best_streak` в `GET /reports/calendar/all` |
| **`GroupMember.streak`** | ✅ Пересчёт consecutive при каждом отчёте |
| **Insights** | ✅ Rule-based `insights[]` в `calendar/all` (≥3 успешных дней) |
| **«Темп цикла»** | ✅ `cycle_pace_percent` — доля успешных дней за последние 30 |
| **Праймы vs успешные дни** | Документировано; insight `multi_group_days` при расхождении |

---

## 6. Справочник API (кратко)

```
User.prime_points          # int, default 0
User.successful_days       # int, default 0
User.can_create_custom_skills  # bool, prime_points >= 10

GET  /reports/calendar?group_id=
GET  /reports/calendar/all     # + current_streak, best_streak, cycle_pace_percent, insights[]
POST /reports                  # body: group_id, content_text, status
GET  /users/me/prime-events
GET  /achievements

GroupMember.streak / best_streak
group.team_pulse             # embedded in GET /groups/{id}
POST /groups/{id}/check-in   # body: { "kind": "done"|"starting"|"support"|"hard" }
```

---

## 7. Аналитика (события, не метрики)

См. `lib/core/analytics/analytics.dart` — воронки onboarding, habits, registration.  
Analytics-события **не дублируют** бизнес-метрики; источник истины — backend + `User` / `HabitReport`.

---

## 8. QA

| Проверка | Команда / артеfact |
|----------|-------------------|
| Отчёт → +1 Prime | `prime-backend/tests/test_reports.py` |
| Календарь all | `test_global_calendar_counts_reports_across_all_skills_once_per_day` |
| Home state / metrics | `test/home_state_test.dart`, `tests/test_metrics_engine.py`, `tests/test_calendar_streak.py` |
| Manual E2E | [11-E2E-QA-CHECKLIST.md](./11-E2E-QA-CHECKLIST.md) |

---

**Версия:** 2026-07-27 · Product v2 · синхронизировано с `prime-backend` + `prime-flutter` на дату документа.
