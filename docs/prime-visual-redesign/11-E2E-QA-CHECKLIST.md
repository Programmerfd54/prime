# E2E QA Checklist — Manual two-device sign-off

Ручная проверка на **двух клиентах** (iOS + Android или два симулятора) после product v2.

**Автоматический gate перед ручным прогоном:**

```bash
./scripts/e2e-automated-gate.sh
```

Ожидание: **40 pytest + 112 flutter test**, без analyzer errors.

---

## Подготовка

- [ ] Backend запущен (`prime-backend/docker-compose.yml` → `http://127.0.0.1:8080`)
- [ ] Flutter client указывает на тот же API (`lib/config/api_config.dart` / env)
- [ ] Два тестовых аккаунта с **accepted** дружбой:

```bash
cd prime-backend
python3 tools/seed_e2e_pair.py --base-url http://127.0.0.1:8080/api/v1
```

| Устройство | Email | Password | Nickname |
|------------|-------|----------|----------|
| A (Alpha) | `e2e.alpha@example.com` | `E2ePrime123!` | `@e2ealpha` |
| B (Beta) | `e2e.beta@example.com` | `E2ePrime123!` | `@e2ebeta` |

- [ ] Оба клиента на одной версии сборки (commit / build number одинаковые)
- [ ] На устройстве A — очистить кэш приложения перед сценарием avatar (по желанию)

---

## Product v2 — onboarding & sync

| # | Шаг | Ожидание |
|---|-----|----------|
| P1 | Device A: logout → пройти 8-step onboarding, выбрать программу + цель | Завершение без ошибок |
| P2 | Device A: register/login после onboarding | Prefs push на backend (`PATCH /users/me/preferences`) |
| P3 | Device A: Skills → bookmark привычки | Favorite sync (`POST /users/me/favorites/{id}`) |
| P4 | Device A: reinstall / fresh login | Pull prefs + favorites с сервера |
| P5 | Device B: login `@e2ebeta` | Свои prefs не перезаписывают Alpha |

---

## Product v2 — Home & Habits

| # | Шаг | Ожидание |
|---|-----|----------|
| H1 | Home без группы | Editorial hero, «следующий шаг» (new user / search) |
| H2 | Home с active group, отчёт не отправлен | CTA «отчёт» / report due state |
| H3 | Habits → recommendation hero | Программа из onboarding prefs (если задана) |
| H4 | Habit detail v2 → compare sheet | Статичное сравнение программ открывается |

---

## Product v2 — Groups social center

| # | Шаг | Ожидание |
|---|-----|----------|
| G1 | Active group → Team pulse | `completed/total`, сообщение RU |
| G2 | Check-in «Выполнил» / «Нужна поддержка» | POST check-in, список обновляется |
| G3 | Recap недели | Действия / темп / лучший день — **только если есть отчёты** |
| G4 | Milestones strip | Progress или ✓ unlock по реальным данным |
| G5 | Два устройства в одной группе | Pulse друг друга после отчёта / check-in |

---

## Product v2 — Profile & privacy

| # | Шаг | Ожидание |
|---|-----|----------|
| PR1 | Profile → growth section | Серия, успешные дни, Праймы из API |
| PR2 | Prime history | Список событий после ready-отчёта |
| PR3 | Settings → privacy toggles | Public profile B скрывает выбранные поля |
| PR4 | Device B → public profile A | Уважаются privacy flags |

---

## Avatar upload

| # | Шаг | Ожидание |
|---|-----|----------|
| A1 | Профиль → Аватар → Галерея, JPEG ≤5 МБ | Preview, progress, успех |
| A2 | Сразу после upload — аватар на Profile, Chats inbox, Public profile друга | Новое фото **без restart** |
| A3 | Профиль → Аватар → Камера | Снимок загружается |
| A4 | Профиль → Аватар → Удалить | Placeholder initial, DELETE на backend |
| A5 | Upload на клиенте 1 → открыть профиль на клиенте 2 (pull/refresh) | Фото друга обновилось |
| A6 | Файл >10 МБ (источник) | Сообщение «Максимальный размер — 10 МБ» |
| A7 | Неподдерживаемый формат (GIF) | Сообщение о формате |

---

## Direct chat attachments

| # | Шаг | Ожидание |
|---|-----|----------|
| D1 | Личный чат Alpha↔Beta → + → Фото ≤10 МБ | Preview, progress, bubble с image |
| D2 | Личный чат → + → Файл PDF ≤25 МБ | File bubble, tap opens |
| D3 | Фото >10 МБ | Отказ до отправки |
| D4 | Файл >25 МБ | Отказ до отправки |
| D5 | Отправка на клиенте 1 | На клиенте 2 появляется ≤3 с (polling) |
| D6 | Offline → отправка → online | Retry / sync без дубликатов |
| D7 | Cancel upload mid-flight | Composer очищен, повтор возможен |

---

## Regression smoke (visual)

- [ ] Home, Habits, Groups, Chats, Profile — editorial surfaces, не pure black
- [ ] Text scale 200% — без overflow на pilot screens (`editorial_inventory_test.dart`)
- [ ] `./scripts/e2e-automated-gate.sh` green перед релизом

---

## Автоматизированное покрытие (CI / pre-E2E)

| Область | Тест |
|---------|------|
| MIME / limits | `test/media_validation_test.dart` |
| Avatar bytes | `test/avatar_upload_test.dart` |
| URL cache bust | `test/media_urls_test.dart` |
| Composer UI | `test/chat_composer_smoke_test.dart` |
| AppAvatar | `test/app_avatar_test.dart` |
| a11y 200% | `test/text_scale_smoke_test.dart`, `test/editorial_inventory_test.dart` |
| Pilot + inventory goldens | `test/pilot_golden_test.dart`, `test/editorial_inventory_test.dart` |
| Home state machine | `test/home_state_test.dart` |
| Onboarding prefs | `test/onboarding_preferences_test.dart` |
| Group recap backend | `tests/test_group_recap.py` |
| Metrics engine | `tests/test_metrics_engine.py`, `tests/test_calendar_streak.py` |
| Prefs/favorites sync | `tests/test_user_personalization.py` |
| **Gate script** | `scripts/e2e-automated-gate.sh` |

---

## Sign-off

| Поле | Значение |
|------|----------|
| Tester | _______________ |
| Дата | _______________ |
| Сборка (commit) | _______________ |
| Device A | _______________ |
| Device B | _______________ |
| Automated gate | ☐ pass |
| Product v2 (P/H/G/PR) | ☐ pass |
| Avatar (A1–A7) | ☐ pass |
| DM attachments (D1–D7) | ☐ pass |
| Visual smoke | ☐ pass |

**Подпись:** _______________
