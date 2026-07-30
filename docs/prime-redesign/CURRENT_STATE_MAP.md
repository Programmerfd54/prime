# PRIME V6 — Current State Map (Phase 0 Baseline)

> Generated: 2026-07-30 · Contract: `PRIME_Composer_2_5_Designer_PM_Mega_Prompt` V6  
> Discovery method: code-first (Flutter repo), no per-screen screenshots required for baseline.

## Stack & platforms

| Item | Value |
|------|-------|
| Flutter | 3.44.8 |
| Dart | 3.12.2 |
| State | Provider (`ChangeNotifier`) |
| Navigation | Navigator 1.0 + named routes (`AppRoutes`) |
| Web | Path URL strategy enabled |
| Fonts | Manrope (variable), global via `PrimeTypography` |
| Design systems | Dual: `lib/design/*` tokens + `lib/ui/kit/*` presentation |
| Breakpoints | Tablet 840px (`AppBreakpoints`), compact 600px (`PrimeBreakpoints`) |

## Auth & gate flow (`AppGate`)

```
Splash/loading → Onboarding (8 steps) → Auth → ProfileSetup → MainShell
```

| Gate state | Screen | Route alias |
|------------|--------|-------------|
| `auth.initializing` | Loading + brand | `/` |
| `!onboardingDone` | `OnboardingScreen` | `/onboarding` |
| `!isAuthenticated` | `AuthScreen` | `/auth` |
| `!profileCompleted` | `ProfileSetupScreen` | — |
| Authenticated | `MainShell` | tab routes |

## Main shell tabs (`MainShell`, IndexedStack)

| Index | Tab | Route | Screen |
|-------|-----|-------|--------|
| 0 | Привычки | `/skills` | `SkillsScreen` |
| 1 | Группы | `/groups` | `GroupsScreen` |
| 2 | Главная | `/`, `/home` | `DashboardScreen` |
| 3 | Чаты | `/chats` | `ChatsScreen` |
| 4 | Профиль | `/profile` | `ProfileScreen` |

## Named routes (`AppRoutes`)

| Pattern | Screen / loader | Purpose |
|---------|-----------------|---------|
| `/group/:id` | `GroupDetailScreen` | Active/waiting group room |
| `/skills/:id` | `SkillDetailRouteLoader` | Habit detail |
| `/chat/group/:id` | `GroupChatRouteLoader` | Team chat |
| `/chat/direct/:id` | `DirectChatRouteLoader` | 1:1 chat |
| `/profile/:id` | `PublicProfileRouteLoader` | Public profile |
| `/settings` | `AccountSettingsScreen` | Legacy settings entry |
| `/avatar` | `AvatarScreen` | Avatar picker |

## Screen inventory (26 top-level screens)

### Onboarding & auth
- `OnboardingScreen` — 8-step PageView (promise → goals → quit history → program preview → …)
- `AuthScreen` — login/register, email verification
- `ProfileSetupScreen` — nickname, region, avatar
- `ForgotPasswordScreen`, `ResetPasswordScreen`

### Habits
- `SkillsScreen` — catalog, filters, search
- Skill detail via `AppHabitDetailV2` / route loader

### Groups lifecycle
- `GroupsScreen` — search / waiting / active states via `GateGroupsPresentation`
- `GroupDetailScreen` — pact, members, reports, team pulse
- `GroupChatScreen` — team messaging

### Home & reports
- `DashboardScreen` — daily focus, challenge card, mood, direct chats strip
- `PrimeHistoryScreen` — history / analytics entry

### Chats & social
- `ChatsScreen` — tabs: Личные / Команда / Люди (`GateChatsPresentation`)
- `DirectChatScreen` — 1:1 thread + composer
- `PublicProfileScreen` — view profile, friend request, «Написать»

### Profile & settings
- `ProfileScreen`, `EditProfileScreen`
- `SettingsHubScreen` + detail screens (account, appearance, ritual, privacy, password, support)
- `TournamentsScreen`, `AvatarScreen`

## ChatsScreen state machine

```
ChatsScreen
├── Tab: Personal (_isPersonal)
│   ├── loading → inbox skeleton
│   ├── empty → CTA discover friends
│   └── data → DirectChat rows
├── Tab: Team (!_isPersonal && !_isPeople)
│   ├── empty → «Команда ещё не собрана»
│   └── data → GroupChat rows
└── Tab: People (_isPeople)
    └── UsersDiscoverPanel (asSliverHost in CustomScrollView)
        ├── region filter dropdown
        ├── local filter (≥2 chars)
        ├── nickname lookup (≥3 chars)
        └── add-friend / open chat actions
```

**Recent fixes (session):** sliver host layout (hit-test crash), `_DiscoverAddButton` (infinite width in Row), non-blocking `_initChat`, Telegram-style composer/bubbles.

## Group state (conceptual, from `GroupsScreen` + providers)

| State | UI surface | Primary action |
|-------|------------|----------------|
| No group | Search CTA | Start team search |
| Searching | Waiting companion | View pool stats |
| Team proposed | Member list + accept/decline | Confirm slot |
| Introduction | Buddy room | Send intro |
| Pact pending | Contract sheet | Sign pact |
| Scheduled start | Countdown | — |
| Active (day N/30) | Group detail + report | Submit daily report |
| Completion | Summary / continuation vote | Continue 60/90/… |

## Key providers & sync

| Provider | Role |
|----------|------|
| `AuthProvider` | Session, onboarding flag, profile |
| `ChatsInboxProvider` | Inbox list, unread |
| `RealtimeClient` | WS events, message delivery |
| `ChatSyncController` | Per-thread sync |
| `WaitingRoomPoller` | Group match polling |
| `ThemeModeController` | Light/dark |

## Design tokens (existing V2/V5 baseline)

- `PrimeColors` — semantic roles incl. `bubbleOutbound`, `bubbleInbound`
- `PrimeTypography.family` = Manrope
- `AppTokens` / `design/tokens.dart` — spacing, radii, motion
- Chat: `AppChatComposer`, `AppChatMessage`, `AppMessageBubble`, `AppChatShell`

## Test baseline (2026-07-30)

| Command | Result | Notes |
|---------|--------|-------|
| `flutter analyze` | PASSED (179 info/warnings, 0 errors) | Mostly `prefer_const` |
| `flutter test` | FAILED | 265 passed, 6 failed (goldens) |

### Pre-existing / golden failures

1. `pilot_golden_test.dart` — home greeting (~8.6% diff)
2. `profile_v3_gate_test.dart` — 02 own about filled (~31%), 03 completeness (~0.06%)
3. `v5_visual_gate_test.dart` — waiting companion (size mismatch), groups search (size mismatch), chat shell (~8.6%)

> Regressions from intentional V6 chat UI must update goldens after visual acceptance, not be masked.

## Backend gaps (frontend-visible)

See `docs/prime-ux-overhaul/BACKEND-GAPS.md` and `lib/core/network/backend_gaps.dart`. Notable: realtime delivery latency, friend graph consistency, group slot replacement API.

## Risk register (Phase 0)

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dual design systems (`design/` vs `ui/kit/`) | Inconsistent surfaces | Phase 1 token unification |
| Golden drift during redesign | CI red | Update per vertical slice after acceptance |
| Nested scroll in Chats People tab | Layout crashes | Sliver host pattern (done) |
| Large scope Phase 2–5 | Schedule | Feature flags per V6 §24A |

## Analytics hooks (sample)

- `Analytics.onboardingStarted/StepViewed/Abandoned`
- Home/group/report events via `core/analytics/analytics.dart`

---

**Phase 0 gate:** route map ✓ · state map ✓ · test baseline documented ✓ · benchmark → `BENCHMARK_MATRIX.md` · decisions → `DESIGN_DECISIONS.md`
