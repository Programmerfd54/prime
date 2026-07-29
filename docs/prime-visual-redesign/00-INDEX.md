# PRIME Visual Redesign — индекс этапов

Полный визуальный и UX-редизайн Flutter-клиента ПРАЙМ в направлении Apple × Notion × calm wellness, с фирменным фиолетовым акцентом.

Предыдущий пакет [`../prime-ux-overhaul/`](../prime-ux-overhaul/) закрыл foundation/activation. Этот пакет — зрелый visual language и миграция всех реальных экранов на единую DS.

## Правила

1. Не создавать параллельную `design_system/` — рефакторить `prime-flutter/lib/design/` и `prime-flutter/lib/ui/`.
2. Не создавать demo-копии экранов. Изменения только на реальных маршрутах.
3. Терминология UI: **привычка**, команда/группа, цикл 30 дней, Праймы, отчёт — `prime-flutter/lib/l10n/copy.dart`.
4. Фиолетовый — акцент (CTA, active tab, progress, focus, selected, rewards), не заливка.
5. После этапа: `flutter analyze`, `flutter test`, обновить статусы здесь и в MD этапа.
6. Приёмка: [ACCEPTANCE.md](./ACCEPTANCE.md).

## Статус этапов

| Этап | Файл | Статус | Следующее действие |
|------|------|--------|--------------------|
| 1. Visual audit | [01-visual-audit.md](./01-visual-audit.md) | **done** | Inventory зафиксирован |
| 2. Foundations | [02-foundations.md](./02-foundations.md) | **done** | Tokens / type / theme |
| 3. Core components | [03-core-components.md](./03-core-components.md) | **done** | Buttons, inputs, nav, app bars |
| 4. Auth & onboarding | [04-auth-onboarding.md](./04-auth-onboarding.md) | **done** | Auth → profile setup → onboarding |
| 5. Home & habits | [05-home-habits.md](./05-home-habits.md) | **done** | Dashboard + skills |
| 6. Groups & profile | [06-groups-profile.md](./06-groups-profile.md) | **done** | Groups + profile |
| 7. Friends & chats | [07-friends-chats.md](./07-friends-chats.md) | **done** | Search + chats |
| 8. Polish & QA | [08-polish-a11y-qa.md](./08-polish-a11y-qa.md) | **done** | A11y, motion, tests |
| Gap analysis | [10-PURPLE-EDITORIAL-GAP.md](./10-PURPLE-EDITORIAL-GAP.md) | **done** | Code ~100%; см. 09-GAP для истории |
| Product roadmap v2 | [12-PRODUCT-REDESIGN-ROADMAP.md](./12-PRODUCT-REDESIGN-ROADMAP.md) | **active** | Backend sync, E2E |
| Metrics glossary | [13-METRICS-DEFINITIONS.md](./13-METRICS-DEFINITIONS.md) | **done** | §17 canonical definitions |
| Visual upgrade v2 | [14-visual-v2.md](./14-visual-v2.md) | **done** | Fonts, light islands, charts, scenes |
| Product upgrade v3 | [15-product-v3.md](./15-product-v3.md) | **done** | Home/habits/groups, live search, realtime, chats, retention |
| E2E QA | [11-E2E-QA-CHECKLIST.md](./11-E2E-QA-CHECKLIST.md) | **gate ready** | `seed_e2e_pair.py` + automated gate |
| Onboarding step map | [16-ONBOARDING-STEP-MAP.md](./16-ONBOARDING-STEP-MAP.md) | **done** | UI-шаг ↔ `_page` ↔ `_stepId`, мэтчинг = CTA в `SkillDetailScreen` |

## Порядок

```text
01 visual-audit ✓
    → 02 foundations ✓
        → 03 core-components ✓
            → 04 auth-onboarding ✓
                → 05 home-habits ✓
                    → 06 groups-profile ✓
                        → 07 friends-chats ✓
                            → 08 polish-a11y-qa ✓
                                → ACCEPTANCE
```

## Команды проверки

```bash
cd prime-flutter && flutter analyze && flutter test
```

## Ключевые пути кода

- Токены: `prime-flutter/lib/design/tokens.dart`
- Типографика: `prime-flutter/lib/design/typography.dart`
- Тема: `prime-flutter/lib/config/theme.dart`
- Компоненты: `prime-flutter/lib/ui/components/`
- Состояния: `prime-flutter/lib/ui/states/`

## Легенда

- `[x]` done
- `[~]` partial
- `[ ]` todo
- `[!]` blocked
