# PRIME V5 — UI/UX Mega Prompt

> Evolution of V4 foundations. Reference: Apple HIG softness, Dribbble HR/ecosystem cards, PRIME gate screens.  
> Last updated: 2026-07-29

## Philosophy

- **Product, not prototype** — every screen answers "what do I do next?"
- **Dark canvas first** — `#0F0D14`; no white leaks, no milky overlays
- **Apple-soft glass** — blur + **dark tint** under content; 1px top rim only (α ≤ 0.10)
- **Solid cards in lists** — glass only for nav, dock, sheets, hero overlays
- **One type scale** — Manrope via `AppTypography` (Kit/Profile forward)

## Glass recipe (PrimeGlassV5)

```
ClipRRect
  └ BackdropFilter(σ)
      └ ColoredBox(canvasTint α .72–.86)
          └ 1px top edge highlight (α ≤ .10)
              └ content
```

**Never:** white specular gradient > 15% opacity on dark surfaces.

## Surface ladder

| Level | Use |
|-------|-----|
| canvas | Screen bg |
| solid | Lists, forms, settings rows |
| accent | Hero CTAs, search state |
| glass | Dock, sheets, toolbar, photo controls |
| modal | Bottom sheets, action menus |

## Typography (V5 unified)

| Role | Style | Size |
|------|-------|------|
| Page title | `AppTypography.pageTitle` | 32/w700 |
| Section | `AppTypography.sectionTitle` | 22/w700 |
| Card title | `AppTypography.cardTitle` | 17/w600 |
| Body | `AppTypography.body` | 15/w400 |
| Caption | `AppTypography.caption` | 12/w500 |

## Screen anatomy

### Home (`GateHomePresentation`)

States via `HomeStateResolver`:
- **newUser** — journey strip, habit CTA
- **searchingTeam** — hero progress + `HomeWaitingCompanion` (regional stats, prep checklist, motivation, friends CTA)
- **active cycle** — calendar, team pulse, report composer
- **teamMatched** — confirm CTA

### Groups (`GroupsScreen`)

- Page hero (habit name, scope pill)
- **Scope toggle**: Мой город / Вся Россия + live `region_searching` count
- Expand timer when `!canExpandSearch`
- Vertical timeline (сейчас → расширение → частичный старт)
- Readiness checklist → «Что ускорит подбор»
- Confirmation card: `X/6 подтвердили`

### Chats

- Unified `AppChatShell` for team + DM
- Empty personal → friends discovery module
- Segment: Команда / Личные

### Profile

- Photo scrim from top (α 0.20 min)
- Dark glass controls on photo
- `ProfileActionBar`: primary + burger menu

### Settings

- Segmented privacy presets
- Custom disclosure (not Material ExpansionTile)
- Glass sheets for dialogs

## Search functional spec

1. Join queue → region from profile
2. Show `region_searching` / `skill_searching` from `GET /groups/waiting-room/stats`
3. If low local count → suggest expand
4. After 15 min → `can_expand_search` → `POST /groups/waiting-room/expand`
5. Match → group `introduction` → each member `confirmed_participation` → `rules_pending` → `active`

## Toasts (`PrimeToast`)

Variants: success, error, warning, info, loading.  
Slow action (>2.5s): «Долго грузится, ждём сервер».

## Copy bank

- Expand confirm: «Искать по всей России?»
- Friends empty: «Добавьте друзей — двигайтесь вместе»
- Bell loading: skeleton in sheet, not blocking tap

## Acceptance

- `v5_glass_policy_test` — no white α > 0.15 in glass layers
- Visual gate V5 goldens
- Bell opens sheet < 100ms perceived
