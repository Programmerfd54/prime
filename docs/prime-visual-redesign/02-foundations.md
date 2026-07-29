# Stage 2 — Foundations

**Status:** done  
**Depends on:** Stage 1

## Цель

Единые токены цвета, типографики, отступов, радиусов, elevation, motion и Material theme без neon-шума.

## Файлы

- `prime-flutter/lib/design/tokens.dart`
- `prime-flutter/lib/design/typography.dart`
- `prime-flutter/lib/design/motion.dart`
- `prime-flutter/lib/config/theme.dart`

## Чеклист

- [x] Палитра: background / surface / elevated / primary / text / border / semantic
- [x] Gold сузить до rare achievements
- [x] `AppElevation` (почти без теней)
- [x] Radius: sm=12, md=16, lg=20, xl=24, pill
- [x] Icon sizes: 16 / 20 / 24 / 28
- [x] Bottom content inset token (`AppSpacing.bottomNavClearance`)
- [x] Typography: Display / LargeTitle / Title1 / Title2 / Body / BodySecondary / Caption / Button
- [x] Веса ≤ w600–w700; системный нейтральный стек (без Montserrat)
- [x] Theme: solid primary, input radius из токенов, calm AppBar
- [x] Motion durations: press / transition / state

## Критерии

1. Нет новых hex вне `tokens.dart`.
2. ThemeData завязан на токены.
3. `flutter analyze` clean (только prefer_const info).
