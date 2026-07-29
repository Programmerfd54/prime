# Purple Editorial Wellness — Visual Gap Analysis

Сравнение текущего состояния ПРАЙМ (после editorial pass) с целевым brief «Purple Editorial Wellness».

## Screen inventory (24 экрана)

| Экран | Роль | Статус редизайна |
|-------|------|------------------|
| onboarding_screen | Первый контакт | Editorial hero ✓ |
| auth_screen | Вход | Editorial hero ✓ |
| forgot/reset_password | Восстановление | Editorial ✓ |
| profile_setup_screen | Онboarding профиля | Editorial ✓ |
| main_shell | Навигация | Floating tonal bottom nav ✓ |
| dashboard_screen | Центр дня | AppHomeGreeting + bento metrics ✓ |
| skills_screen | Каталог привычек | Фильтры + vertical rows + SVG art ✓ |
| groups_screen | Команда | Empty/matched + active searches banner ✓ |
| group_detail_screen | Активная группа | Hero + intro/rules/voting editorial ✓ |
| group_chat_screen | Групповой чат | AmbientCanvas + editorial composer ✓ |
| chats_screen | Inbox | Social rows + AmbientCanvas loading/error ✓ |
| direct_chat_screen | Личный диалог | Composer + attachments + AmbientCanvas ✓ |
| profile_screen | Identity | AppProfileHero ✓ |
| avatar_screen | Аватар | Full flow + cache bust + AmbientCanvas ✓ |
| account_settings_screen | Настройки | AppSettingsSection + change password ✓ |
| public_profile_screen | Профиль друга | AppPublicProfileHero + metrics ✓ |
| tournaments_screen | Orphan stub | Editorial empty state; нет route |

## Почему всё ещё ощущалось как Flutter MVP

### 1. Однородный чёрный фон
**Было:** `#0C0B10` на всём canvas — ощущение «ночного Android».  
**Сделано:** tonal levels `background`, `backgroundElevated`, `surfaceSoft`, `accentSurface`, `heroSurface*`. Ambient orbs на pilot-экранах.

### 2. Одинаковые карточки
**Было:** border + surface на всех сущностях.  
**Сделано:** editorial panels для groups (intro, rules, voting, searches), habits (catalog row, unlock card), home hero. ~55% из 13 card archetypes.

### 3. Чаты без social depth
**Было:** текст only, пустой composer.  
**Сделано:** `AppChatComposer`, image ≤10 МБ, file ≤25 МБ, preview, progress, full-screen image, inbox preview. Group chat — editorial composer + media (photo/video note).

### 4. Avatar broken
**Было:** `MultipartFile.fromFile` (web fail), нет cache eviction, нет delete.  
**Сделано:** bytes upload, bottom sheet (gallery/camera/delete), `AppAvatar` + cache bust, backend DELETE `/users/me/avatar`.

### 5. Generic habit icons
**Было:** Material icons / neon placeholders.  
**Сделано:** 7 SVG illustrations в `assets/habits/`, `HabitArtObject` с `flutter_svg` + painter fallback.

## Moodboard specification

- **Tone:** premium lifestyle / wellness, взрослый, не neon
- **Surfaces:** deep graphite + violet undertone, не pure black
- **Purple usage:** ambient fields, progress, selection — не заливка всех CTA
- **Type:** Manrope body + редкий display для hero (Google Fonts, кириллица)
- **Motion:** 150–360ms, без bounce; haptics на send/nav/destructive
- **Art:** HabitArtObject SVG (7 assets); `NeonSkillIcon` / `skill_visuals.dart` удалены

## Component inventory (целевой)

| Категория | Компонент | Статус |
|-----------|-----------|--------|
| Foundations | tokens.dart | ✓ |
| Profile | AppAvatar, AppProfileHero | ✓ |
| Chat | AppChatComposer, AppChatMessage | ✓ |
| Editorial | AmbientCanvas, AppHeroModule, HabitArtObject | ✓ |
| Groups | AppGroupListRow, AppGroupEmptyState, AppGroupIntroPanel, … | ✓ |
| Habits | AppHabitListRow, AppHabitDetailInfoPanel, AppCustomHabitUnlockCard | ✓ |
| Cards | 13 archetypes | ~85% (legacy `AppHabitCard`, `AppChatTile` removed) |
| Home | AppFriendSearchPanel | ✓ |
| Nav | AppBottomNavigation, AppNavigationRail | ✓ |

## Migration plan

1. **Done:** tokens, avatar, attachments, habits SVG, groups editorial, public profile, settings, group chat parity (`AppGroupChatMessage`), NeonSkillIcon→HabitArtObject, `lib/widgets/` slim (2 files), legacy card/tile widgets removed
2. **Code complete:** AmbientCanvas on all chat flows + avatar + skill detail; `flutter test` 83 green
3. **Manual only:** E2E avatar/attachments QA on two physical devices — `11-E2E-QA-CHECKLIST.md`
4. **Optional post-v1:** Rive/Lottie accents, full-screen golden inventory, tournaments route wiring

## Критерии готовности (delta)

| Критерий | Статус |
|----------|--------|
| Avatar без restart | ✓ code |
| Direct image 10 МБ | ✓ client + backend |
| Direct file 25 МБ | ✓ client + backend |
| Realtime (polling) | ✓ dedupe + server id |
| Не pure black theme | ✓ tokens |
| Habit SVG illustrations | ✓ v2 editorial ring |
| Legacy App*Card widgets | removed |
| Все 24 экрана editorial | ~100% code (tournaments orphan) |
| flutter test | ✓ 83 tests |
