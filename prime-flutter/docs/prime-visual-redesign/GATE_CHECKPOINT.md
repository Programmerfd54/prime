# PRIME Visual Reset — Foundation Gate Checkpoint

## Demo accounts (password: `DemoPrime123!`)

| Scenario | Email | Nickname |
|----------|-------|----------|
| **Filled** (primary) | `demo-filled@example.com` | `@demofilled` |
| **Empty** | `demo-empty@example.com` | `@demoempty` |
| **Matching** | `demo-matching@example.com` | `@demomatch` |

Seed (dev only):

```bash
docker cp prime-backend/tools/seed_demo_scenarios.py prime-api:/app/tools/seed_demo_scenarios.py
docker cp prime-flutter/assets/avatars/demo prime-api:/app/demo_avatars
docker exec -e ALLOW_DEMO_SEED=1 prime-api python3 tools/seed_demo_scenarios.py --yes --reset
```

## Run web + capture

```bash
cd prime-flutter
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
cd build/web && python3 -m http.server 8765
# Chrome at 390×844 — login manually or:
python3 scripts/capture_visual_gate.py --base-url http://127.0.0.1:8765
```

Captures land in `docs/prime-visual-redesign/gate-captures/`.

## Stage completion summary

| Stage | Status | Notes |
|-------|--------|-------|
| A Geometry | ✅ | `squirclePath` fixed; dock capsule; unit test |
| B Seeder | ✅ | `tools/seed_demo_scenarios.py`; derived metrics |
| C Kit | ✅ | `lib/ui/kit/` — 12 archetypes + sans scale |
| C Nav | ✅ | `PrimeBottomNavigation` wired via `AppBottomNavigation` |
| D Home | ✅ | `GateHomePresentation` — single composition |
| D Habits | ✅ | Sans catalog, `PrimeImageCard` grid |
| D Detail | ✅ | Single hero title; `PrimeContextualActionBar` |
| D Chats | ✅ | Flat segment; `PrimeListRow`; friend search sheet |
| D Profile | ✅ | `PrimeProfileCard`; analytics empty-state gate |
| E Capture | ⚠️ | Script + partial headless shots; **confirm filled/empty in Chrome** |

## Self-review vs gate criteria

| Criterion | Result |
|-----------|--------|
| Distinct pages (not one template) | ✅ Surface ladder + archetypes per job |
| One clear visual focus per screen | ✅ Hero/accent cards; removed accordion noise |
| Sans working UI | ✅ Headers, catalog, chats, profile, nav |
| No chamfered standard cards | ✅ Global squircle fix (Stage A) |
| Capsule nav (not hexagon) | ✅ `PrimeBottomNavigation` |
| Meaningful filled data | ✅ Seeder: day 22/30, team 6, history |
| Empty state quality | ✅ `PrimeEmptyState` / `PrimeAccentCard` |
| Mobile density | ✅ Compact metrics, 68–72 rows, nav inset |
| Still unmistakably PRIME purple | ✅ Brand preserved; semantic accents added |

## Reference attribution

| Screen | Positive ref | Key change vs negative |
|--------|--------------|------------------------|
| Home | VibeMove home | One hero + 3 metrics + team pulse; no duplicate accordions |
| Habits | VibeMove workouts | Photo grid varied ratios; no purple wash on all tiles |
| Detail | Fitness detail | Edge hero + measured CTA bar |
| Chats | Hiring app rows | Flat segment; list rows; search in sheet |
| Profile | Hiring + finance dash | Cover hero; semantic analytics colours |

## Tests

- `test/squircle_geometry_test.dart` — geometry regression
- Golden suite intentionally **red** (geometry migration); non-golden analyze clean on gate files
- Run: `flutter test test/squircle_geometry_test.dart`
