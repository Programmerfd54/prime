# PRIME redesign — delivery summary (2026-07-28)

## Verification

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors (infos only) |
| `flutter test` | **193 passed** (was 142) |
| `flutter build web` | ✓ Built `build/web` |
| `flutter build apk` | Skipped — no Android SDK in this environment |
| Backend `pytest` | **64 passed** |

## Design system

- Brand purple **kept**: `#8B5CF6` / `#6D28D9`
- New semantic layer: `lib/design/theme/` — `PrimePalette`, `PrimeColors` ThemeExtension, `PrimeTheme`, `context.prime`, `PrimeBreakpoints`
- `AppColors` → theme-aware getters via `ThemeBinding` (light/dark resolve across all call sites)
- `AppTypography` colorless scale + `metricLarge`/`metricCompact`; ink from TextTheme
- Real **light + dark** themes; persisted `ThemeMode` in Settings → Внешний вид
- Liquid Glass: brightness-aware tint; dock no longer forces blur (respects reduce-motion)

## Product / UX

- Named routes + path URL strategy + persisted tab index (`lib/core/navigation/`)
- Onboarding step map: `docs/prime-visual-redesign/16-ONBOARDING-STEP-MAP.md`
- Matching CTA aligned to «Найти команду»; region expansion stays honest (not all-skills)
- Group chat upload parity (10/25 MB, preview, progress, CancelToken, retry)
- Avatar optimistic preview + stale-cache fixes
- Offline report queue + DM `client_id` dedupe
- Engines: Momentum, Consistency, Recovery, Habit Fit, Reminder, Rhythm Map
- Analytics events + full HTTP failure mapping

## Goldens

Dark goldens regenerated after theme foundation. New light golden: `test/goldens/light_hero_module.png`.
