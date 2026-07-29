# Stage 1 — Visual audit

**Status:** done

## Цель

Зафиксировать карту экранов, inventory компонентов, визуальный долг и дубли перед миграцией.

## Карта экранов

| Экран | Файл | Роль |
|-------|------|------|
| Onboarding | `lib/screens/onboarding_screen.dart` | 3-page carousel |
| Auth | `lib/screens/auth_screen.dart` | register / login |
| Forgot password | `lib/screens/forgot_password_screen.dart` | recovery request |
| Reset password | `lib/screens/reset_password_screen.dart` | set new password |
| Profile setup | `lib/screens/profile_setup_screen.dart` | post-auth |
| Home | `lib/screens/dashboard_screen.dart` | next step, calendar, friends, chats preview |
| Habits + detail | `lib/screens/skills_screen.dart` | grid + `SkillDetailScreen` |
| Groups | `lib/screens/groups_screen.dart` | matchmaking, list |
| Group detail | `lib/screens/group_detail_screen.dart` | members, reports, votes |
| Group chat | `lib/screens/group_chat_screen.dart` | group messenger |
| Chats | `lib/screens/chats_screen.dart` | DM inbox |
| Direct chat | `lib/screens/direct_chat_screen.dart` | 1:1 |
| Profile | `lib/screens/profile_screen.dart` | self + achievements |
| Public profile | `lib/screens/public_profile_screen.dart` | other user |
| Avatar | `lib/screens/avatar_screen.dart` | upload |
| Settings | `lib/screens/account_settings_screen.dart` | + ChangePasswordScreen |
| Tournaments | `lib/screens/tournaments_screen.dart` | stub, not in tabs |
| Shell | `lib/screens/main_shell.dart` | bottom nav |

Friends search — секция в dashboard. Achievements / calendar — вложены.

## Component inventory

**DS (`lib/ui/components/`):** buttons, fields, cards, header, scaffold, bottom nav, chat tile/bubble, dialogs, snackbar, skeletons, status badge.

**States (`lib/ui/states/`):** empty, loading, error, connection banner.

**Legacy:** `PrimeHeader`, `PrimeLoader`, `AsyncErrorView`, `StatCard`, `NeonSkillIcon`.

## Визуальный долг

- Typography: w800–w900, Montserrat, много inline `TextStyle`
- ~111× Material `Colors.white*` на крупных экранах
- Magic spacing (110/112 bottom inset), radius 8–28 вне шкалы
- Floating purple capsule nav
- Neon glow на skills / avatar / achievements
- Dual AppBar paths; dual SnackBar/Dialog paths
- Private card clones на dashboard/groups/profile

## Дубли

| Паттерн | Где |
|---------|-----|
| Private home cards | `_HomeNextStepCard`, `_ActiveChallengeCard`, … |
| Search cards | `_SearchCard`, `_MatchedTeamCard` |
| Raw ElevatedButton | group_detail, avatar, change password |
| Raw SnackBar | groups, group_detail, group_chat, … |
| Stock AppBar | push-экраны vs AppHeader на табах |

## Терминология

UI: привычка / команда / группа. Код/API: `Skill*`. Табы: Привычки · Группы · Главная · Чаты · Профиль.
