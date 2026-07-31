# Moderation Test Matrix

Date: 2026-07-31  
Run: `cd prime-backend && pytest tests/test_security_remediation.py -v`

## Automated regression (CI)

| ID | Case | Input / action | Expected | Test |
|---|---|---|---|---|
| MT-01 | Push token hijack | Register same token on two users | 409; token stays on owner | `test_device_token_cannot_be_hijacked` |
| MT-02 | Media scope match | Valid URL same group | 200 path (no raise) | `test_media_url_requires_matching_upload_scope` |
| MT-03 | Cross-group media | Group A URL in Group B | 403 | same |
| MT-04 | Pending media attach | `pending://` before scan | 409 | same |
| MT-05 | Quarantine clean | Worker processes asset | `processing_status=CLEAN` | same |
| MT-06 | EN profanity HIGH | `"this is a fuck test"` | `allowed=false`, HIGH | `test_profanity_detects_english_high_confidence` |
| MT-07 | Allowlist safe | `"classic assistant document"` | `allowed=true` | `test_profanity_allows_scunthorpe_safe_word` |
| MT-08 | HIGH → restriction | Publish profane group message | `PROFANITY_REJECTED` + 18h ban | `test_high_confidence_profanity_applies_18h_restriction` |
| MT-09 | Restricted block | Second message while banned | `SOCIAL_WRITE_RESTRICTED` | same |
| MT-10 | No restriction extend | Profane again while banned | Same `expires_at` | `test_restriction_not_extended_by_blocked_attempt` |

## Manual / QA matrix

| ID | Case | Steps | Expected |
|---|---|---|---|
| MT-11 | RU HIGH profanity | Send Cyrillic lexicon term in group chat | 403 `PROFANITY_REJECTED`, restriction active |
| MT-12 | MEDIUM band | Borderline term (if configured) | 403 `PROFANITY_QUARANTINED`, no restriction |
| MT-13 | Empty message | Whitespace-only chat send | Allowed or validation error per router; no crash |
| MT-14 | Profile about moderate | PATCH `/users/me` toxic about | 403 moderation error |
| MT-15 | Reaction text | Add profane reaction emoji/text | Blocked same as messages |
| MT-16 | Appeal create | POST appeal with valid `decision_id` | 201; audit `moderation.appeal.created` |
| MT-17 | Duplicate appeal | Same decision twice | 409 |
| MT-18 | Appeal REVERSE | Moderator step-up + REVERSE | Restriction revoked; `GET /users/me/restriction` inactive |
| MT-19 | Moderator without MFA | Call `/ops/moderation/appeals` with enforce on | 403 step-up required |
| MT-20 | TOTP step-up | Enroll + verify TOTP | Step-up session; ops endpoint 200 |

## Evasion probes

| ID | Technique | Example | Expected |
|---|---|---|---|
| MT-21 | Spacing | `f u c k` | HIGH if compact match |
| MT-22 | Mixed case | `FuCk` | HIGH after normalize |
| MT-23 | Punctuation | `f.u.c.k` | Depends on compact rules |
| MT-24 | Allowlist substring | `"assistant"` in safe word | Allowed (Scunthorpe) |
| MT-25 | Mixed RU/EN | Combined script insult | MIXED language tag in decision |

## Integration surfaces

| Surface | Endpoint | Moderation hook |
|---|---|---|
| Group chat | `POST /chat/{group_id}/messages` | `moderate_text_before_publish` |
| DM | `POST /direct-chats/{friend_id}/messages` | same |
| Profile | `PATCH /users/me` | same on text fields |
| Media | upload + send | `validate_media_url_for_scope` |

## Sign-off checklist

- [ ] All MT-01–MT-10 green in CI
- [ ] MT-11–MT-14 spot-checked on staging
- [ ] Moderator MFA enrolled on staging admin accounts
- [ ] Appeal flow tested end-to-end
- [ ] Policy version recorded in release notes

## Failure triage

| Symptom | Check |
|---|---|
| False positive surge | Allowlist + lexicon diff |
| No restriction applied | `user_restrictions` table, decision `confidence_band` |
| Media attach 403 | `media_uploads.scope_type/scope_id` |
| Ops 403 | `moderator_step_up_sessions.expires_at` |
