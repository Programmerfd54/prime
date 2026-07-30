# Profile V3 Visual Acceptance (TZ §41)

Gate screenshots: `docs/profile-v3/gate/` (copied from `test/goldens/profile_v3/`).

Regenerate:

```bash
flutter test test/profile_v3_gate_test.dart --update-goldens
cp test/goldens/profile_v3/*.png docs/profile-v3/gate/
```

## §41 checklist

| # | File | Scenario |
|---|------|----------|
| 1 | `01_own_filled_overview.png` | Framed photo, tags, metrics, tabs, chart |
| 2 | `02_own_about_filled.png` | «О себе» with bio, focus, 2×2 facts |
| 3 | `03_own_completeness.png` | Empty profile completeness strip + CTA |
| 4 | `04_public_with_photo.png` | Public profile + action bar |
| 5 | `05_public_no_photo.png` | Public profile without photo |
| 6 | `06_public_overview.png` | Stats row + info rows + about |
| 7 | `07_public_compatibility.png` | Explainable reasons (no %) |
| 8 | `08_public_more_menu.png` | Context menu |
| 9 | `09_own_progress_21d.png` | Cycle (tinted) + analytics (dark) |
| 10 | `10_own_achievements.png` | Achievements (warm hero + carousel) |
| 11 | `11_compact_phone.png` | 375×812 |
| 12 | `12_web_medium.png` | 900×844 |

## V3 vs V2 (negative baseline)

| Area | V2 baseline | V3 |
|------|-------------|-----|
| Photo | Full-bleed to edges | Inset 13px, radius 23, profile shell |
| Surfaces | Single `#242424` cards | canvas / shell / warm / tinted / analytics |
| About | List: date, age, city | Bio, focus, 2×2 facts, tags, team status |
| Layout | Long scroll | Tabs: Обзор / Прогресс / Привычки / Достижения |
| Public | Generic rows | Stats, info rows, compatibility tab, Save/Share |
| Compatibility | — | Concrete reasons, no match % |
| Nav clearance | 76px | 100px (`navBottomClearance + 24`) |

## Goldens policy

- **Do not update** `test/goldens/profile_v2/` until V3 visuals are approved.
- V3 gate uses separate `test/goldens/profile_v3/`.

## Contrast / elevation audit (grayscale)

- Canvas `#100D17` vs profile shell `#1A1622` — visible border + shadow
- Shell vs photo frame — inset gap + inner radius
- About card `surfaceWarm` vs canvas
- Cycle `surfaceTinted` vs analytics `surfaceAnalytics`
- Achievements hero `surfaceWarm` vs carousel `surfaceNeutral`
