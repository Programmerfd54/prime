# PRIME UX Overhaul — индекс этапов

Дорожная карта управляемой доработки Flutter-клиента (и минимальных backend-патчей).  
Работаем **по одному этапу**, сохраняя запускаемую сборку после каждой итерации.

## Правила

1. Не фейкать отсутствующие backend-возможности — см. [BACKEND-GAPS.md](./BACKEND-GAPS.md).
2. Не дублировать компоненты: сначала `lib/ui/` и `lib/design/`, потом новые виджеты (сразу на реальном экране).
3. State management: **Provider** (не менять без причины).
4. Терминология UI: **привычка**, команда/группа, цикл 30 дней, Праймы, отчёт — словарь в `prime-flutter/lib/l10n/copy.dart`.
5. После этапа: `flutter analyze`, `flutter test`, обновить статусы в соответствующем MD и в таблице ниже.
6. Общая приёмка продукта: [ACCEPTANCE.md](./ACCEPTANCE.md).

## Статус этапов

| Этап | Файл | Статус | Следующее действие |
|------|------|--------|--------------------|
| 1. Foundation & blockers | [01-foundation-blockers.md](./01-foundation-blockers.md) | **done** | Полный чеклист закрыт (error boundary + inbox API) |
| 2. Activation UX | [02-activation-ux.md](./02-activation-ux.md) | **done** | Password reset + cancel request + Chats tab |
| 3. Design system | [03-design-system.md](./03-design-system.md) | **done** | Tokens/motion/a11y residual закрыты |
| 4. Polish & tests | [04-polish-tests.md](./04-polish-tests.md) | **done** | Тесты расширены; ACCEPTANCE обновлён |

## Порядок

```text
01 foundation-blockers ✓
    → 02 activation-ux ✓
        → 03 design-system ✓
            → 04 polish-tests ✓
                → ACCEPTANCE прогон
```

## Команды проверки (каждый этап)

```bash
# Backend
cd prime-backend && python3 -m pytest

# Flutter
cd prime-flutter && flutter analyze && flutter test

# Локальный web
# Backend: cd prime-backend && docker compose up -d --build prime-postgres prime-api
cd prime-flutter && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## Легенда статусов в чеклистах

- `[x]` done — есть в коде и соответствует критерию
- `[~]` partial — начато / частично, нужно дожать
- `[ ]` todo — не сделано
- `[!]` blocked — нужен backend (см. BACKEND-GAPS)

## Связанные документы репозитория

- [README_LOCAL.md](../../README_LOCAL.md) — локальный запуск
- [PRIME_GUIDE.md](../../PRIME_GUIDE.md) — карта продукта
- Код gaps: `prime-flutter/lib/core/network/backend_gaps.dart`
