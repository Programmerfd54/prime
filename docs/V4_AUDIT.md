# PRIME V4 — Repository Audit & Rollout Status

> Spec source: `PRIME_Opus_5_UI_UX_Mega_Prompt (1).md` (MASTER PROMPT V4)  
> Negative baseline: current PRIME screenshots (Jul 2026)  
> Positive references: image(47)–image(59), Nixtio/HR Hiring profile composition  
> Last updated: 2026-07-29

## Visual Gate (V4.14) — PASSED

Nine reference compositions are implemented as presentation widgets and covered by golden tests:

| # | Screen | Widget | Golden |
|---|--------|--------|--------|
| 01 | Home (active cycle) | `GateHomePresentation` | `test/goldens/v4_visual_gate/01_home_active.png` |
| 02 | Groups (searching 1/6) | `GateGroupsPresentation` | `02_groups_searching.png` |
| 03 | Chats list (filled) | `GateChatsPresentation` | `03_chats_filled.png` |
| 04 | Conversation (filled) | `GateConversationPresentation` | `04_conversation_filled.png` |
| 05 | Profile owner (filled) | `GateProfilePresentation` | `05_profile_owner_filled.png` |
| 06 | Home (new user) | `GateHomePresentation` | `06_home_new_user.png` |
| 07 | Chats (empty) | `GateChatsPresentation` | `07_chats_empty.png` |
| 08 | Notifications (empty) | `GateNotificationCenterSheet` | `08_notifications_empty.png` |
| 09 | Groups (confirmation 6/6) | `GateGroupsConfirmationCard` | `09_groups_confirmation.png` |

Review copies: `docs/v4-visual-gate/*.png`  
Test file: `prime-flutter/test/v4_visual_gate_test.dart` (9/9 green)

**Glass policy (V4):** Cards and content blocks use solid kit surfaces (`PrimeContentCard`, `kitSurfaceDecoration`). Frosted blur is allowed only via `PrimeGlassSurface`, `LiquidGlass` / `LiquidGlassDock` — navigation, bottom dock, sheets, photo overlays. Legacy `GlassContainer` (`design/glass.dart`) **removed**; guarded by `test/v4_glass_policy_test.dart`.

- [x] Mass legacy golden update (pilot, adaptive, editorial, profile_v2, charts, light theme)
- [x] All `lib/screens/` and kit components use solid V4 surfaces

---

## Foundations (V4.1–V4.6) — DONE

| Component | Path | Notes |
|-----------|------|-------|
| Dark canvas palette | `design/theme/prime_palette.dart` | `#0F0D14` canvas, semantic ink/surface tokens |
| `PrimeGlassSurface` | `design/prime/prime_glass_surface.dart` | navigation / toolbar / sheet / contextMenu variants; opaque fallback |
| White-leak fix | `design/liquid/liquid_glass.dart` | top specular only; dark tint |
| Bottom sheets | `ui/components/app_dialog.dart` | sheets → `PrimeGlassSurface.sheet` |
| Profile surfaces | `ui/kit/presentation/profile_surfaces.dart` | dark PRIME shells (V4.7: no large beige hero) |
| Profile hero | `ui/kit/presentation/profile_editorial_widgets.dart` | Nixtio-style photo + scrim + dark data panel |
| Segmented tabs | `ui/kit/presentation/profile_tabs.dart` | pill control |
| Kit export | `ui/kit/prime_kit.dart` | exports `PrimeGlassSurface` |

---

## Screen Inventory & Rollout

| Screen / route | Product goal | Baseline problem | V4 target | Status |
|----------------|--------------|------------------|-----------|--------|
| Splash / boot | Fast restore | Generic purple orb | Branded minimal loader | **Wired** (`AppLoadingState` + `PrimeBrandMark` boot) |
| Auth / onboarding | First value | Template forms | Editorial one-action screens | **Wired** (auth + onboarding → `PrimeContentCard`, canvas) |
| **Home / dashboard** | Daily rhythm | Flat cards, weak hierarchy | Hero + categories + metrics + team pulse | **Gate + wired** (`dashboard_screen` → `GateHomePresentation`) |
| **Groups / matching** | Find team of 6 | Heavy glass, cluttered checklist | Radial progress + readiness checklist | **Gate + partial wire** (`_SearchCard` → `GateGroupsPresentation`) |
| **Chats inbox** | Team + DM | Slow load, glass leak on invite | Segmented list + semantic cards | **Gate + partial wire** (invite card → `PrimeContentCard`) |
| **Direct chat** | Support + pairing | Basic bubbles | V4 conversation chrome + quick replies | **Wired** (`AppChatAppBar`, `AppMessageBubble`, `GateConversationSkeleton`) |
| **Profile owner** | Identity + progress | Beige/stacked cards | Dark hero + tabs + rhythm chart | **Gate + wired** (`ProfileHeroCard`, `ProfileTabBar`) |
| Public profile | Trust before team | Small avatar | Same hero composition | **Partial** (`public_profile_screen`) |
| Settings / privacy | Control | Milky glass sheets | Opaque semantic sections | **Partial** (sheets use `PrimeGlassSurface`) |
| Notifications bell | Actionable inbox | Provider-coupled | Glass panel + SSE | **Wired** (`GateNotificationCenterSheet` via bottom sheet) |
| Skills catalog | Choose habit | Legacy tiles | Image-forward program cards | **Wired** (`PrimeImageCard`, `PrimeContentCard`, detail sections) |
| Group detail / chat | Team cycle | Mixed styles | Align with gate patterns | **Wired** (editorial heroes → `PrimeContentCard`, radial progress, photo thumbs) |

---

## Performance (pre-V4 plan, retained)

| Area | Change | Path |
|------|--------|------|
| Inbox dedupe | SWR + shared provider | `ChatsInboxProvider`, `ApiClient` cache |
| Direct chat hydrate | Cache-first + inline skeleton | `direct_chat_screen.dart` |
| Profile instant paint | Hero from `AuthProvider` | `profile_screen.dart` |
| Backend N+1 | Batch inbox queries | `prime-backend/.../group_service.py` |

---

## Remaining V4 Scope (post-gate rollout)

### P0 — Core tab parity
- [x] Wire `ChatsScreen` to `GateChatsPresentation` (segment + list + invite)
- [x] V4 conversation chrome: `AppChatAppBar`, `AppMessageBubble`, `AppChatComposer`, loading skeleton
- [x] Wire `DirectChatScreen` to V4 chrome (`AppChatAppBar`, `AppMessageBubble`, `GateConversationSkeleton`)
- [x] Groups: searching → `GateGroupsPresentation`
- [x] Groups: confirmation + active cycle → `GateGroupsConfirmationCard`, `GateGroupsActiveCycleCard`, `GateGroupsListTile`
- [x] Settings sections → `PrimeContentCard` (opaque), theme picker via `showAppBottomSheet`
- [x] Edit profile inputs → `PrimeTextField` V4 tokens
- [x] Notification center sheet visual pass (`GateNotificationCenterSheet`)
- [x] Auth form shell → `PrimeContentCard`, canvas background
- [x] Onboarding canvas → `ProfileSurfaces.canvas`
### P1 — Full app
- [x] Onboarding interactive cards → `PrimeContentCard` (replace remaining `GlassContainer`)
- [x] Skills detail canvas → `ProfileSurfaces.canvas`
- [x] Skills catalog cards → `PrimeImageCard` + `PrimeContentCard`; habit detail sections → `PrimeContentCard`
- [x] Splash branded loader (`PrimeBrandMark` + boot label in `AppGate`)
- [x] Group detail / chat — canvas, opaque status strips (no glass leak)
- [x] Empty states for gate screens (06–09)
- [x] Web expanded layouts + bottom inset consistency (`KitLayout.tabScrollPadding`, `PrimeTabContentFrame`, chats split ≥840px)
- [x] Light theme parity goldens (`light_hero_module`, `light_content_card`)

### P2 — Product extras (V4.11–V4.13)
- [x] Demo seeder (dev-only, deterministic fixtures) — `docs/V4_DEMO_SEEDER.md`, `prime-backend/tools/seed_demo_scenarios.py`
- [x] Functional gate tests (bell, matching flow) — `test/v4_functional_gate_test.dart`
- [x] Hero module / bento / habit catalog tiles → solid V4 surfaces
- [x] Legacy goldens updated (`pilot`, `adaptive`, `editorial_inventory`, `profile_v2`, `charts`)
- [x] Remaining glass: `prime_history`, `avatar`, `tournaments` → `PrimeContentCard`
- [x] Infra glass removed: `AppCard`, `PrimeSurface`, `PrimeContentCard.glass` → solid only
- [x] Legacy pilot cards (`ui/components/cards/*`) → `kitSurfaceDecoration` / solid; mood chart + sheet → `PrimeContentCard` + `showAppBottomSheet`
- [x] Legacy `GlassContainer` removed (`design/glass.dart` deleted); policy test `v4_glass_policy_test.dart`

---

## Acceptance Checklist (V4.14)

- [x] Foundations: palette, glass, no white leaks on sheets
- [x] 9 visual gate presentations (filled + empty)
- [x] Gate golden tests green
- [x] Goldens exported to `docs/v4-visual-gate/`
- [x] Empty-state gate screenshots (06–09)
- [x] Demo seeder documented (`docs/V4_DEMO_SEEDER.md`)
- [x] Functional gate tests green (`test/v4_functional_gate_test.dart`)
- [x] Legacy glass removed; policy guard (`test/v4_glass_policy_test.dart`)

---

## Commands

```bash
# Visual gate
cd prime-flutter && flutter test test/v4_visual_gate_test.dart

# Functional gate (matching, notifications)
cd prime-flutter && flutter test test/v4_functional_gate_test.dart

# Light theme goldens
cd prime-flutter && flutter test test/light_theme_golden_test.dart

# Glass policy guard
cd prime-flutter && flutter test test/v4_glass_policy_test.dart

# Update gate goldens (after intentional visual change)
cd prime-flutter && flutter test test/v4_visual_gate_test.dart --update-goldens
```
