# Stage 3 — Design system completion

**Status:** done  
**Depends on:** Stage 2 (чтобы компоненты сажались на финальные сценарии)  
**Out of scope:** новая state-management библиотека; отдельный demo-gallery экран

## Цель

Единая DS без разрозненных hex/glow по экранам; недостающие компоненты из спеки — **только с подключением к реальным экранам**.

## Уже есть

- [x] `lib/design/tokens.dart` — AppColors, spacing, radius, control heights, durations, breakpoints
- [x] `AppTheme` завязан на токены
- [x] Components: Primary/Secondary button, Text/Password field, HabitCard, ChatTile, StatusBadge
- [x] States: Loading / Empty / Error / ConnectionBanner
- [x] Max content width shell на wide web

## Чеклист недостающих компонентов

| Компонент | Статус | Куда подключено |
|-----------|--------|-----------------|
| AppScaffold | [x] | account_settings / direct_chat |
| AppHeader | [x] | profile + groups |
| AppBottomNavigation | [x] | `main_shell.dart` |
| AppTextButton | [x] | auth toggle |
| AppIconButton | [x] | DM send |
| AppSearchField | [x] | friend search на Home |
| AppDropdownField | [x] | region на profile_setup |
| AppTextarea | [x] | report + about |
| AppCheckbox | [x] | agreement на auth |
| AppCard | [x] | groups empty + profile about |
| AppMetricCard | [x] | dashboard metrics |
| AppProfileCard | [x] | public_profile |
| AppAchievementCard | [x] | profile achievements |
| AppGroupCard | [x] | groups list |
| AppMessageBubble | [x] | direct_chat_screen |
| AppSkeleton | [x] | skills + dashboard |
| AppInlineError | [x] | auth + profile_setup |
| AppSnackbar | [x] | `showAppSnackBar` |
| AppDialog / AppBottomSheet | [x] | stop search / primes / about gate |
| AppTypography | [x] | `lib/design/typography.dart` |

## Унификация / долг

- [x] Убрать избыточный neon glow на nav / cards
- [x] Заменить hardcoded `Color(0x…)` на экранах на токены
- [x] `AsyncErrorView` → thin wrapper над `AppErrorState`
- [x] `PrimeLoader` → thin wrapper / `AppLoadingState` на экранах
- [x] Удалён orphan `statistics_screen.dart`
- [x] Semantics / tooltips на icon-only controls
- [x] Tap targets ≥ 48dp
- [x] Reduce motion: `AppMotion` + `MediaQuery.disableAnimations`

## Адаптивность

- [x] Scrollable forms + keyboard insets на auth (`resizeToAvoidBottomInset`)
- [x] Long name/description overflow на cards (ellipsis / Expanded)
- [x] Text scale 100–200% smoke (`test/text_scale_smoke_test.dart`)
- [x] Landscape safe areas (`SafeArea` left/right + desktop frame padding)

## Критерии приёмки Stage 3

1. Ключевые экраны Stage 2 используют DS-компоненты.
2. Нет demo-only экрана DS.
3. `flutter analyze` clean.
4. Визуально: спокойный premium dark, фиолетовый как акцент.

## Команды

```bash
cd prime-flutter && flutter analyze && flutter test
```
