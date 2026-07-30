# PRIME Profile V2 — Visual Acceptance (§21, §31)

Reference: `image(64).png` (Nixtio HR-profile composition).  
Negative baseline: screenshots 29.07 (Daniil/Ivan profiles).

| Область | Было | Стало | Референс |
|---|---|---|---|
| Font | Poppins + fallback кириллицы | Manrope global + CupertinoTheme | `image(64).png` |
| Hero | Пустой фиолетовый баннер / oversized crop | Photo-led card, taupe no-photo monogram | `image(64).png` |
| Tags | Отсутствуют / generic | PRIME habit tags, pastel fills | `image(64).png` |
| Metrics | Одинаковые grey capsules | 4 varied compact cells 54–64px | `image(64).png` |
| Chart | Пустой generic block | Integrated «Ритм за 30 дней» + dashed среднее | `image(64).png` |
| Header actions | Glossy spheres | 44×44 rounded-square Lucide stroke | TZ §26 |
| CTA | Yellow full-width capsule | Purple `#6D28D9` rounded 15px | PRIME hierarchy |
| Menu | Weak glass over CTA | Opaque sheet (mobile) / anchored menu (desktop) | TZ §27 |
| Achievements | Generic medal emoji | Per-tier Lucide icons, radius 19, progress | TZ §30 |
| Expanded | Single column only | Hero+sections split + NavigationRail | TZ §16 |
| States | Generic errors | Offline / blocked / network / skeleton | TZ §14 |

## §31 Screenshot gate (390×844 unless noted)

Captures written to `docs/profile-v2/gate/` via:

```bash
cd prime-flutter
python3 scripts/capture_profile_v2_gate.py --base-url http://127.0.0.1:8765 --api-url http://127.0.0.1:8080/api/v1
```

| # | File | Scenario |
|---|---|---|
| 1 | `01_own_filled.png` | demo-filled@example.com — own profile with photo |
| 2 | `02_own_empty.png` | demo-empty@example.com — new/empty profile |
| 3 | `03_public_filled.png` | Public participant with avatar |
| 4 | `04_public_no_photo.png` | Public profile without photo (monogram) |
| 5 | `05_context_menu.png` | Context menu open |
| 6 | `06_analytics_filled.png` | Filled analytics section |
| 7 | `07_analytics_empty.png` | Empty analytics card |
| 8 | `08_achievements.png` | Achievements carousel |
| 9 | `09_web_medium.png` | 900×844 medium layout |
| 10 | `10_long_bio.png` | Long Russian name + bio |

## §20 Seeded account verification

`demo-filled@example.com` (seed: `prime-backend/tools/seed_demo_scenarios.py`):

- 21+ day cycle history
- 6 team members
- Active habit «Утренний фокус»
- Achievements + analytics data

Automated check: `flutter test test/profile_seeded_data_test.dart`

## Goldens

Widget goldens: `flutter test test/profile_v2_goldens_test.dart --update-goldens`

Golden files: `test/goldens/profile_v2/`

**Do not update goldens until visual gate screenshots are approved.**
