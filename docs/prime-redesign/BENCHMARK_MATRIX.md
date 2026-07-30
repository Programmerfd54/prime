# PRIME V6 — Benchmark Matrix

> Research date: 2026-07-30 · Products evaluated for **patterns**, not pixel copy.

## Method

For each PRIME user scenario we reviewed leading mobile products (2024–2026 UX norms), extracted **transferable mechanics**, and mapped to PRIME constraints (Manrope, violet brand, accountability-not-shame, real API data).

| Scenario | Benchmark products | PRIME adaptation |
|----------|-------------------|------------------|
| Onboarding & habit choice | Duolingo, Headspace, Streaks | 8-step progressive disclosure; program preview from real skill catalog |
| Team search & waiting | Bumble BFF, Match.com queue, Discord server discovery | Waiting companion with live pool stats; no fake counters |
| Group pact & intro | Notion templates, DocuSign micro-commit | Inline pact with member avatars; timezone contract block |
| Daily report | Strava activity post, Apple Fitness rings | Single primary CTA on home; report composer ≤3 taps |
| 1:1 & team chat | Telegram, WhatsApp, iMessage | See chat section below |
| People discovery | Telegram global search, LinkedIn | Nickname lookup + region filter; `@nickname` display |
| Profile & trust | Linear profile, GitHub | Editorial profile v3; completeness meter |
| Notifications | iOS grouped notifications, Slack | Actionable rows; deep link to route |
| Settings & account | iOS Settings hierarchy | Hub → detail; ritual/appearance grouped |

---

## Chat & messaging (Phase 6 focus)

### Telegram
- **Composer:** pill input, circular send (arrow), attach via sheet
- **Bubbles:** tail on last in group, timestamp inline, avatar on group edges
- **Adopt for PRIME:** pill composer + circular brand send; outbound avatar; profile action in app bar

### WhatsApp
- **Composer:** expanding multiline field, mic/send morph (out of scope v1)
- **Read receipts:** double check — PRIME uses delivery status from API when present
- **Adopt:** multiline growth up to max height; attachment preview strip above input

### iMessage
- **Bubble grouping:** collapse metadata for consecutive same-sender
- **Adopt:** `_groupMeta` in `AppChatMessage` — show avatar/time only on group boundaries

### Slack (team context)
- **Thread reply preview** above composer
- **Adopt:** `replyPreview` chip in `AppChatComposer` (existing prop)

### Anti-patterns (do NOT copy)
- Literal Telegram green / WhatsApp teal
- Stickers/GIF drawer before core report flow stable
- Public read receipts that shame missed reports

---

## Onboarding (Phase 2)

| Pattern source | Mechanism | PRIME use |
|----------------|-----------|-----------|
| Duolingo | One question per screen, progress dots | Already 8 steps; tighten primary CTA hierarchy |
| Headspace | Soft illustration + single choice | Use official habit photography, not stock |
| Streaks | Quit history without guilt copy | `_quitCount` / `_attemptCount` — supportive tone |

---

## Groups pre-start (Phase 3)

| Pattern source | Mechanism | PRIME use |
|----------------|-----------|-----------|
| Discord | Server readiness checklist | 6/6 member grid with empty slots |
| Airbnb co-host | Timezone + availability | Explicit timezone contract row |
| DocuSign | Scroll-to-enable sign | Pact scroll + checkbox + CTA |

---

## Home & active cycle (Phase 4)

| Pattern source | Mechanism | PRIME use |
|----------------|-----------|-----------|
| Apple Fitness | Ring + one action | Day progress + «Отчёт за сегодня» |
| Strava | Feed card with media | Report card with photo thumb |
| Linear | Command palette feel | Quick actions without clutter |

---

## Profile (Phase 6)

| Pattern source | Mechanism | PRIME use |
|----------------|-----------|-----------|
| Nixtio HR refs (V6 art direction) | Editorial typography, soft cards | `profile_editorial_widgets` |
| GitHub | Public vs own view parity | `PublicProfileScreen` / `ProfileScreen` |

---

## Scoring (applicability 1–5)

| Scenario | Telegram | WhatsApp | Duolingo | Linear | Strava |
|----------|----------|----------|----------|--------|--------|
| Chat composer | 5 | 4 | — | — | — |
| Chat bubbles | 5 | 4 | — | — | — |
| Onboarding | — | — | 5 | 3 | — |
| Waiting room | 3 | — | — | 4 | — |
| Daily report | — | — | 4 | — | 5 |
| Profile | — | — | — | 5 | 4 |

**Selected defaults for PRIME V6 chat vertical slice:**
1. Pill composer + 44px circular send (`AppChatComposer`)
2. Bubble tails + grouped meta (`AppMessageBubble`, `AppChatMessage`)
3. App bar profile shortcut (`DirectChatScreen`)
4. People tab: sliver list + compact add button (`UsersDiscoverPanel`)
5. Instant thread open: cache-first `_initChat`

---

## Sources

- [Cometchat — Chat app design best practices](https://www.cometchat.com/blog/chat-app-design-best-practices)
- [Sendbird — Chat UI elements](https://sendbird.com/blog/resources-for-modern-chat-app-ui)
- Telegram iOS ChatController architecture (interaction closure pattern — inspiration for state object, not code port)
