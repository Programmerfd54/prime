# PRIME — карта шагов онбординга (Phase 5b)

Канонический маппинг UI-шагов интерактивного онбординга на внутренние индексы кода
и продуктовый смысл каждого шага. Источник истины для кода —
`prime-flutter/lib/screens/onboarding_screen.dart` (`_page`, `_stepId`).

Связанные документы: [04-auth-onboarding.md](./04-auth-onboarding.md),
[13-METRICS-DEFINITIONS.md](./13-METRICS-DEFINITIONS.md).

---

## 1. Таблица шагов

`OnboardingScreen` использует `PageController` с 8 страницами. UI показывает
`${_page + 1} / 8` (1-based) в заголовке; код индексирует страницы с 0
(`_page`, 0-based) и присваивает каждой странице стабильный `_stepId` —
используется в аналитике (`onboarding_step_viewed`, `onboarding_abandoned`).

| UI-шаг (1-based) | `_page` (0-based) | `_stepId` | Продуктовый смысл | Что видит пользователь |
|---|---|---|---|---|
| 1 | 0 | `promise` | **Обещание продукта** — зачем вообще ПРАЙМ | Hero-заставка, оффер «меняться проще с командой из пяти», proof-pills (30 дней / команда из 6 / 1 действие в день), ссылка «Уже есть аккаунт? Войти» |
| 2 | 1 | `problem` | Проблема — почему привычки не приживаются в одиночку | Вопросы «сколько раз начинали / бросали» + инсайт-карточка + график ритма |
| 3 | 2 | `programs` | Выбор направления/программы | Сетка из 6 официальных программ (`OnboardingProgramPreview`), обязательный выбор (блокирует «Далее») |
| 4 | 3 | `daily` | **Как выглядит один день** — механика действие→отчёт | `OnboardingDayFlow`: слайдер-скраббер по «Утро / День / Вечер» с чип-индикаторами выбранного состояния (choice-cards feel) |
| 5 | 4 | `team` | Команда из 6 держит темп | `OnboardingTeamRing` — визуализация команды, блок «Почему шесть» |
| 6 | 5 | `progress` | **Ваш прогресс — наглядно** | `OnboardingMetricsPreview`: кольца Серия/Праймы/Темп + текстовый разбор, что означает каждая метрика, дневная активность, итог «к 30 дню» |
| 7 | 6 | `goal` | **Цель пользователя** (для рекомендации привычки) | `OnboardingGoalPicker` — карточки-чипы целей (до 3), после выбора — карточка с honest-текстом последствия выбора каждой цели |
| 8 | 7 | `summary` | Итоговый план перед регистрацией | `OnboardingSummaryCard` — программа, цели, что дальше; кнопка «Создать аккаунт» |

## 2. Явное соответствие из задания Phase 5b

| Утверждение | Проверка в коде |
|---|---|
| **UI-шаг 1 = promise** | `_page == 0` → `_stepId(0) == 'promise'` — hero + proof-pills + один CTA «Продолжить» |
| **UI-шаг 4 = daily** | `_page == 3` → `_stepId(3) == 'daily'` — `OnboardingDayFlow` (механика действие/отчёт) |
| **UI-шаг 6 = progress** | `_page == 5` → `_stepId(5) == 'progress'` — `OnboardingMetricsPreview` |
| **UI-шаг 7 = goal** | `_page == 6` → `_stepId(6) == 'goal'` — `OnboardingGoalPicker` |

## 3. Запуск мэтчинга — НЕ шаг 7

Важно: выбор цели на шаге 7 (`goal`) влияет только на **рекомендацию** программы
(`OnboardingPreferences.recommendedSkillId`, читается позже в `skills_screen.dart`
через `_onboardingPrefs.recommendationReason`). Сам онбординг никогда не
запускает поиск команды напрямую — на последнем шаге (`summary`) кнопка
«Создать аккаунт» только сохраняет `PendingSearch` (см.
`core/pending/pending_search.dart`) и открывает регистрацию.

Реальный запуск мэтчинга (`POST /waiting-room`) происходит из **CTA внутри
`SkillDetailScreen`** (`prime-flutter/lib/screens/skills_screen.dart`,
`_SkillDetailScreenState._joinGroup`), когда пользователь на экране деталей
привычки нажимает «Найти команду» — это отдельный, осознанный шаг уже после
онбординга (или сразу после регистрации, если есть `PendingSearch`). Онбординг
и мэтчинг — разные жизненные циклы; шаг 7 UI не должен путаться с этим CTA.

## 4. Аналитика по шагам

| Событие | Когда | Payload |
|---|---|---|
| `onboarding_started` | `initState()` экрана | — |
| `onboarding_step_viewed` | `PageView.onPageChanged` (и первичный рендер `_page=0`) | `step` (0-based), `step_id` |
| `onboarding_step_completed` | Нажатие «Продолжить» на шаге, до перехода | `step` |
| `onboarding_skip` | Нажатие «Пропустить» | `page` |
| `onboarding_abandoned` | `dispose()`, если пользователь не дошёл до `_persistAndFinish` (закрыл экран/приложение) | `page`, `step_id` |
| `onboarding_complete` | Успешное завершение (шаг 8 → «Создать аккаунт» или skip) | `goal`, `skill_id` |

## 5. Не менять без обновления этого документа

Если меняется порядок страниц `PageView` в `onboarding_screen.dart`, обязательно
обновить `_stepId()` и таблицу выше в этом файле — иначе аналитика/QA-чеклисты
будут ссылаться на неверный шаг.
