# PRIME V6 — Design Decisions Log

> Decisions are binding for implementation unless superseded by V6 mega prompt.

## DD-001 — Code-first baseline (Phase 0)

**Decision:** Reconstruct product state from Flutter code + tests before requiring screenshots.  
**Rationale:** V6 §3 mandates full frontend study; screenshots are negative baseline only.  
**Status:** Accepted

## DD-002 — Manrope-only typography (Phase 1)

**Decision:** Keep Manrope as sole UI font; no per-screen font drift.  
**Evidence:** `pubspec.yaml`, `PrimeTypography.family`, `typography_policy_test.dart`.  
**Status:** Implemented (pre-V6)

## DD-003 — Chat composer pattern (Phase 6)

**Decision:** Telegram-inspired **pill field + circular brand send**; attach via existing sheet.  
**Rejected:** Full WhatsApp mic/send morph (complexity vs value).  
**Files:** `app_chat_composer.dart`  
**Status:** Implemented

## DD-004 — Message bubble grouping (Phase 6)

**Decision:** Show avatar + timestamp on **group boundaries** only; tail on last bubble in cluster.  
**Rejected:** Avatar on every message (visual noise).  
**Files:** `app_chat_message.dart`, `app_message_bubble.dart`  
**Status:** Implemented

## DD-005 — Outbound avatar (Phase 6)

**Decision:** Show user's avatar on **own** messages (Telegram group style) for parity in 1:1.  
**Props:** `myAvatarUrl`, `myName` on `AppChatMessage`.  
**Status:** Implemented

## DD-006 — People tab layout (Phase 6)

**Decision:** `CustomScrollView` + `SliverMainAxisGroup` + `UsersDiscoverPanel(asSliverHost: true)`.  
**Rejected:** Column with spread children inside parent `ListView` (hit-test crash).  
**Status:** Implemented

## DD-007 — Discover row CTA sizing (Phase 6)

**Decision:** `_DiscoverAddButton` fixed-width compact button instead of `AppPrimaryButton` (`width: infinity`) inside `Row`.  
**Status:** Implemented

## DD-008 — Chat open latency (Phase 6)

**Decision:** `_initChat` sets `_initialized = true` immediately after cache peek; disk/network warm async.  
**Rejected:** Blocking spinner until full sync completes.  
**Status:** Implemented

## DD-009 — Friend fast path to chat (Phase 6)

**Decision:** `PublicProfileScreen` parses `is_friend` from API; «Написать» opens `DirectChatScreen` directly for friends.  
**Status:** Implemented

## DD-010 — Golden updates policy (Phase 7)

**Decision:** Update goldens **only** for intentional visual changes after slice acceptance; never hardcode test data for green CI.  
**Applies to:** `v5_visual_gate_test` chat shell, pilot home if home card changes.  
**Status:** In progress

## DD-011 — Feature flags (Phase rollout)

**Decision:** Use flags from V6 §24A when touching invasive surfaces (`redesign_v6_shell`, `profile_v6`, etc.).  
**Status:** NOT RUN — flags not yet wired in repo

## DD-012 — Glass / glow reduction (Phase 1)

**Decision:** V6 forbids excessive glass and white-violet glow; prefer `PrimeColors.surface*` solids.  
**Evidence:** `glass.dart` removed in working tree; `liquid_glass.dart` constrained.  
**Status:** Partial

## DD-013 — Bottom nav vs content (Phase 1)

**Decision:** Nav must not overlap primary CTA; use `SafeArea` + scroll padding in tab bodies.  
**Status:** Ongoing audit

## DD-015 — Cycle positioning copy (Phase 2)

**Decision:** Mandatory V6 footnote on onboarding summary + step 5 body refresh.  
**Constant:** `OnboardingCopy.cycleContinuationFootnote`.  
**Status:** Implemented

## DD-016 — Primary button V6 spec (Phase 1)

**Decision:** `AppRadius.button = 14`, height 52, neutral `AppElevation.lifted` instead of violet glow.  
**Status:** Implemented

## DD-018 — Team pact replaces shame rules (Phase 3)

**Decision:** `AppGroupRulesPanel` → supportive «Командный договор»; remove shame copy.  
**Status:** Implemented

## DD-019 — Habit continuation block (Phase 2)

**Decision:** All habit details show `AppCopy.cycleContinuationFootnote` in «После 30 дней» section.  
**Status:** Implemented

---

## Open questions

| ID | Question | Owner |
|----|----------|-------|
| OQ-1 | Wire `redesign_v6_*` feature flags? | Eng |
| OQ-2 | Backend: realtime message push SLA | Backend |
| OQ-3 | Profile v3 golden drift — theme change or regression? | Design QA |

---

## Next decisions needed (Phase 2+)

- Onboarding step copy refresh vs current Russian strings
- Official habit photography crop ratios (6 habits)
- Pact scroll legal text source of truth
