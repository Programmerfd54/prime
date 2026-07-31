# Moderation Policy

Date: 2026-07-31  
Policy version: `POLICY_VERSION` in `app/moderation/lexicon.py`  
Detector version: `DETECTOR_VERSION` in `app/moderation/profanity.py`

## Purpose

PRIME is a supportive habit community. This policy defines automated pre-publish moderation for user-generated text in social surfaces: group chat, direct messages, profile fields, and reactions where text is validated.

## Scope

### In scope (server-enforced)

| Surface | `content_type` | Router |
|---|---|---|
| Group chat messages | `group_chat_message` | `chat.py` |
| Group chat reactions | `group_chat_reaction` | `chat.py` |
| Direct messages | `direct_message` | `social.py` |
| DM reactions | `direct_message_reaction` | `social.py` |
| Profile name/about/nickname | `profile_*` | `users.py` |

### Out of scope (this release)

- Image/video content classification (rely on upload validation + malware scan)
- Human review queue for all messages (appeals only)
- Matrix-native moderation bots

## Classification pipeline

1. **Normalize** — lowercase, homoglyph folding, whitespace collapse (`normalize.py`)
2. **Tokenize + compact match** — evasion-resistant matching against RU/EN lexicons
3. **Allowlist** — Scunthorpe-safe tokens (`ALLOWLIST`)
4. **Confidence band** — HIGH / MEDIUM / LOW (`profanity.py`)
5. **Action** — see table below
6. **Audit** — `moderation.decision` event with decision metadata (not raw text)

## Actions by confidence

| Band | Publish | User restriction | HTTP code | Client code |
|---|---|---|---|---|
| **HIGH** | Reject | 18h `SOCIAL_WRITE` | 403 | `PROFANITY_REJECTED` |
| **MEDIUM** | Reject (quarantine) | None | 403 | `PROFANITY_QUARANTINED` |
| **LOW** | Allow | None | — | — |

### SOCIAL_WRITE restriction

- Duration: **18 hours** (`RESTRICTION_HOURS`)
- Blocks: new chat messages, DMs, reactions with text, profile text updates
- Does **not** extend on subsequent violations while active (idempotent)
- Offense idempotency: same `offense_id` does not create duplicate restrictions

## Languages

- Russian (`LEXICON_RU`)
- English (`LEXICON_EN`)
- Mixed detection when both scripts match

## Appeals

Users may appeal a **moderation decision** that affected them:

1. `POST /moderation/appeals` with `decision_id` + optional `explanation` (≤4000 chars)
2. One appeal per decision (409 on duplicate)
3. Moderator resolves via `POST /ops/moderation/appeals/{id}/resolve`:
   - **UPHOLD** — restriction stands
   - **REVERSE** — lifts linked `UserRestriction`, marks decision reversed
   - **ESCALATE** — status `ESCALATED` for human follow-up

Moderator endpoints require **step-up MFA** when `MODERATOR_MFA_ENFORCE=true`.

## User transparency

- Active restriction: `GET /users/me/restriction` returns scope, reason, expiry
- Error payloads include `expires_at` and `confidence` where applicable

## Fail-closed behavior

- If user has active `SOCIAL_WRITE` restriction → `SOCIAL_WRITE_RESTRICTED` before classifier runs
- Pending media URLs (`pending://`) cannot attach to messages (409)

## Policy change process

1. Update lexicon/allowlist in `app/moderation/lexicon.py`
2. Bump `POLICY_VERSION` and/or `DETECTOR_VERSION`
3. Run `MODERATION_TEST_MATRIX.md` cases
4. Deploy backend; no client change required for text-only policy updates

## Escalation to human moderation

| Trigger | Action |
|---|---|
| Appeal submitted | Review within 48h target SLA |
| ESCALATE resolution | Security/on-call notified |
| Repeated MEDIUM band from same user | Manual account review (ops TBD) |

## Legal / safety

Automated profanity filtering is not a substitute for illegal content reporting. Users should use in-app report flows; law enforcement requests follow `INCIDENT_RESPONSE.md` IR-15.
