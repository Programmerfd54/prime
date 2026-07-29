# PRIME Visual Assets Architecture

Единая арт-дирекция для мобильного wellness UI. Без тяжёлых 3D-библиотек.

## Слои

| Слой | Путь | Назначение |
|------|------|------------|
| Ambient | `ambient_and_progress.dart` | Фоновые orbs, progress rings |
| Habit art | `habit_art.dart` | Habit kinds + CustomPainter fallback |
| Scene art | `scene_art.dart` | Soft-3D SVG scenes (default) |
| Charts | `charts/` | Radial, bars, heatmap, team ring, sparkline |
| Editorial | `lib/ui/components/editorial/` | Hero modules, bento, social inbox |
| Static assets | `assets/illustrations/` | Soft-3D SVG scenes |

## Форматы (по приоритету)

1. **SVG soft-3D scenes** — default для habit covers, empty states, onboarding (`assets/illustrations/`)
2. **CustomPainter** — fallback when SVG fails to load; medals, ambient rings
3. **PNG/WebP** — optional raster heroes under `assets/illustrations/`
4. **Lottie** — celebratory states only when needed later

## Правила

- Не использовать Material icon + gradient как «иллюстрацию»
- Каждая сцена уникальна по композиции — не переиспользовать одну кляксу под разными именами
- Purple только в ключевых объектах, не на каждом компоненте
- Optimize: RepaintBoundary on complex painters; SVG stays under ~8 KB

## Добавление новой иллюстрации

1. Добавить SVG в `assets/illustrations/`
2. Extend `SceneKind` / `HabitArtKind` + asset map
3. Wire into editorial card / empty state
