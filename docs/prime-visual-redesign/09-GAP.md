# Честный gap-анализ: спека vs код

> **Актуальный статус:** [10-PURPLE-EDITORIAL-GAP.md](./10-PURPLE-EDITORIAL-GAP.md) — код editorial wave **~100%**.  
> Этот документ фиксирует исходный gap по спеке §34 (foundation + tablet wave).

Полный запрос (~34 раздела) **закрыт на уровне foundation + editorial + tablet + functional fixes (avatar, attachments)**. Остаётся manual E2E и post-v1 polish.

## Сделано

- [x] Visual audit + этапные MD
- [x] Editorial layer + visuals (`AmbientCanvas`, `HabitArtObject`, progress rings)
- [x] Уникальные композиции: главная, привычки, группы, чаты, профиль, achievements
- [x] Auth + onboarding + forgot/reset + profile_setup
- [x] Dashboard decomposed (~608 lines + 5 modules)
- [x] **Tablet NavigationRail** (≥840px) + **chat split-view**
- [x] Desktop frame до 1200px
- [x] Chat polish: date chips, retry, scroll-to-bottom
- [x] Nav haptics (selection)
- [x] Visual assets README
- [x] Editorial smoke tests (6) + adaptive/golden tests (4)
- [x] Golden files: `test/goldens/editorial_*.png`
- [x] `flutter test` green

## Частично

- [~] Golden coverage — 2 editorial modules, не все 34 экрана §31
- [~] Group search animation polish
- [~] Haptics — nav/send/destructive; не все CTA
- [~] Rive/Lottie — architecture documented, assets CustomPainter-only

## Не сделано (post-v1)

- [ ] Golden на каждый экран спеки
- [ ] Physical device Visual QA matrix
- [ ] Полное удаление hardcoded layout numbers

## Вывод

Editorial redesign **выполнен** для продуктовых экранов. Критерий «узнаваемость без текста» — **да** для основных разделов. Следующий этап — asset pipeline (Rive/Lottie) и device QA.
