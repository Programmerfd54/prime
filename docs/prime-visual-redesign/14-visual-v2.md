# 14 — Visual upgrade v2

Статус: **done**

Апгрейд визуального языка: типографика офлайн, светлые острова на тёмном фоне, библиотека графиков, soft-3D иллюстрации, переработка ключевых экранов.

## Цель

Убрать ощущение «дешёвого Android MVP»: системный Roboto, одинаковый тёмно-фиолетовый тон, круги-заглушки вместо иллюстраций, прочерки вместо графиков.

## Сделано

### Типографика
- [x] Manrope + Unbounded в `assets/fonts/` (variable TTF, офлайн)
- [x] `displayHero`, `titleXL`, `numeric` / `numericSm` с tabular figures
- [x] `google_fonts` удалён из runtime-зависимости

### Тоны и поверхности
- [x] Светлые токены: `canvasLight`, `surfaceLight`, `surfaceLightWarm`, `textOnLight*`
- [x] `AppElevation.lifted`
- [x] `lib/design/gradients.dart` — акценты по табам и шагам онбординга
- [x] `lib/design/surfaces.dart` — `PrimeSurface` / `AppSurfaceTone`

### Charts
- [x] `lib/core/metrics/calendar_metrics.dart` + unit-тесты
- [x] `PrimeRadialProgress`, `PrimeWeeklyBars`, `PrimeHeatmap`, `PrimeTeamRing`
- [x] `PrimeTimelinePreview`, `PrimeMoodSwitcher`, `PrimeJourneyStepper`
- [x] `PrimeSparkline`, `PrimeAvatarRing`
- [x] Golden-тесты empty/filled в `test/charts_golden_test.dart`

### Иллюстрации
- [x] `assets/illustrations/` — привычки + сцены
- [x] `SceneArt` / `SceneKind`
- [x] `habit_art.dart` → новая папка; `assets/habits/` удалён

### Экраны
- [x] Главная: зоны температуры, radial + weekly, journey stepper, компактные аватары
- [x] Привычки: mood switcher, full-bleed рекомендация, timeline
- [x] Группы: team ring в пустом состоянии
- [x] Профиль: light «в работе», bars + heatmap, рекорд, insights carousel
- [x] Публичный профиль: «Общее с вами»
- [x] Чаты: сегменты Личные/Команда, avatar rings
- [x] Онбординг: градиенты по шагам, sparkline, live day mock, team ring
- [x] Auth: сегмент прогресса, live password checklist, PrimeTextField
- [x] Profile setup + edit: PrimeTextField
- [x] Account settings: превью приватности, disabled delete с пояснением

## QA

```bash
cd prime-flutter && flutter analyze && flutter test
# после визуальных правок:
flutter test --update-goldens
```

- [x] `flutter analyze` — без error
- [x] Unit: `calendar_metrics_test`
- [x] Goldens: pilot / editorial / adaptive + charts (регенерация после шрифтов)

## Ключевые пути

| Область | Путь |
|---------|------|
| Fonts | `assets/fonts/` |
| Tokens | `lib/design/tokens.dart` |
| Gradients | `lib/design/gradients.dart` |
| Surfaces | `lib/design/surfaces.dart` |
| Charts | `lib/design/visuals/charts/` |
| Metrics | `lib/core/metrics/calendar_metrics.dart` |
| Scenes | `lib/design/visuals/scene_art.dart` |
| Illustrations | `assets/illustrations/` |
