# PRIME — Product Redesign Roadmap (Prime Purple Lifestyle)

Полная спецификация UI/UX v2. Этот документ связывает требования с кодом и фазами.

## Архитектурное решение (важно)

Спека предлагает `lib/design_system/`. **В коде используем существующую систему:**

| Спека | Реализация |
|-------|------------|
| `prime_colors.dart` | `lib/design/tokens.dart` |
| `prime_typography.dart` | `lib/design/typography.dart` |
| `PrimePrimaryButton` | `lib/ui/components/app_primary_button.dart` |
| Editorial cards | `lib/ui/components/editorial/*` |

Не создавать параллельную `design_system/` — расширять `lib/design/` + `lib/ui/`.

---

## Статус по фазам (§30)

### Этап 1 — Audit ✅
- Screen inventory: `docs/prime-visual-redesign/01-visual-audit.md`
- Gap: `10-PURPLE-EDITORIAL-GAP.md` (~100% visual code)
- Backend gaps: `lib/core/network/backend_gaps.dart`

### Этап 2 — Product concept 🔄
| Область | Статус | Следующее |
|---------|--------|-----------|
| Onboarding 6–8 шагов | **Done (8 steps)** | `onboarding_screen.dart`, `onboarding_preferences.dart` |
| Multi-step registration | **Done (3 steps)** | `auth_screen.dart` wizard |
| Habits favorites | **Done (synced)** | `habit_favorites.dart` + API |
| Habits compare | **Done (static UI)** | `app_habit_detail_v2.dart` compare sheet |
| Team pulse / check-in | **Done** | `AppGroupPulsePanel`, `POST /groups/{id}/check-in`, `team_pulse` in group payload |
| Groups recap / milestones | **Done** | `team_recap`, `team_milestones` in `GET /groups/{id}` |
| Profile metrics v2 | **Done** | `app_profile_growth.dart`, insights + streak engine |
| Public profile privacy | **Done** | `privacy_settings` backend + toggles in settings |
| Prime economy screen | **Done** | `prime_history_screen.dart`, `GET /users/me/prime-events` |

### Этап 3 — Design foundations ✅
Tonal purple palette, AmbientCanvas, HabitArtObject, motion, haptics — см. `02-foundations.md`.

### Этап 4 — Pilot screens 🔄
| # | Экран | Visual | Product features |
|---|-------|--------|------------------|
| 1 | Onboarding | ✅ 8-step interactive | ✅ prefs saved |
| 2 | Registration | ✅ 3-step wizard | ✅ nickname debounce |
| 3 | Auth | ✅ editorial hero | login/recovery ok |
| 4 | Home | ✅ adaptive bento | ✅ state machine |
| 5 | Habits | ✅ catalog + rec | ✅ favorites, detail v2, compare |
| 6 | Profile | ✅ hero + growth | ✅ tempo, prime history link |
| 7 | Groups | ✅ editorial | ✅ pulse + check-in + recap |
| 8 | Public profile | ✅ hero + metrics | ✅ privacy respected |

### Этап 5 — Full migration 🔄
Most routes editorial; orphan: `tournaments_screen.dart`.

### Этап 6 — QA ✅ code / ⏳ manual
`flutter test` 112; E2E: `11-E2E-QA-CHECKLIST.md`.

---

## Новые функции — backend dependency

| Функция | Client | Backend |
|---------|--------|---------|
| Onboarding prefs sync | SharedPreferences + `GET/PATCH /users/me/preferences` | ✅ |
| Habit favorites | SharedPreferences + favorites API | ✅ |
| Habit compare | — | static metadata ok |
| Team pulse | `AppGroupPulsePanel` | embedded in `GET /groups/{id}` |
| Check-in reactions | `groupCheckIn()` | `POST /groups/{id}/check-in` |
| Groups recap | `AppGroupRecapPanel` | `team_recap` in group payload |
| Team milestones | `AppGroupMilestonesPanel` | `team_milestones` in group payload |
| Insights | placeholder UI | `calendar/all.insights` rule engine |
| Privacy controls | account settings toggles | user privacy JSON + `_public_user_payload` |
| Prime history | `PrimeHistoryScreen` | `GET /users/me/prime-events` |
| OAuth Apple/Google | — | not in backend |

**Правило:** не показывать статистику без данных; не выдумывать цифры.

---

## Метрики (§17) — определения

См. **[13-METRICS-DEFINITIONS.md](./13-METRICS-DEFINITIONS.md)** — канонический глоссарий (API, UI, known gaps).

Кратко в UI (из API):
- **Праймы** — `User.prime_points`
- **Успешные дни** — `User.successful_days`
- **Серия** — `calendar/all` → `current_streak` (consecutive days)
- **День цикла** — `successful_days` / 30 в Profile hero

---

## Analytics (§29)

Расширено в `lib/core/analytics/analytics.dart`:
- `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_complete`
- `register_step_viewed`
- `habit_saved`, `habit_recommendation_viewed`

---

## Приоритет следующих спринтов

1. **Manual E2E sign-off** — `./scripts/e2e-automated-gate.sh` + [11-E2E-QA-CHECKLIST.md](./11-E2E-QA-CHECKLIST.md) на двух устройствах

---

## Критерии готовности (§32)

| Критерий | Статус |
|----------|--------|
| Onboarding 6–8 интерактивных шагов | ✅ |
| Prefs сохраняются | ✅ client + backend sync |
| Registration premium multi-step | ✅ |
| Habits catalog + recommendation | ✅ |
| Habits favorites | ✅ synced |
| Habit detail v2 + compare | ✅ |
| Groups pulse + check-in | ✅ |
| Groups recap / milestones | ✅ |
| Profile growth + prime history | ✅ |
| Public profile privacy | ✅ |
| Home adaptive state machine | ✅ |
| Golden + a11y inventory | ✅ |
| Backend sync (prefs + favorites) | ✅ |
| Metrics glossary (`13-METRICS-DEFINITIONS.md`) | ✅ |
| All pages new DS | ~95% visual |
| flutter analyze / test | ✅ 112 tests, 48 pytest |
| Metrics engine (streak + insights) | ✅ |
| E2E automated gate | ✅ `scripts/e2e-automated-gate.sh` |
| E2E two devices (sign-off) | ⏳ manual — [11-E2E-QA-CHECKLIST.md](./11-E2E-QA-CHECKLIST.md) |

Финальное ощущение «premium international product» — **visual + product v2 depth достигнуты**; остаётся manual E2E sign-off.
