import '../../design/visuals/habit_art.dart';
import '../../l10n/copy.dart';
import '../../models/group.dart';

/// Adaptive home phases — priority order in [HomeStateResolver.resolve].
enum HomePhase {
  teamMatched,
  searchingTeam,
  groupIntroduction,
  groupRulesPending,
  reportDue,
  reportComplete,
  returningUser,
  newUser,
}

class HomePendingGroup {
  const HomePendingGroup({
    required this.groupId,
    required this.skillName,
    required this.status,
  });

  final String groupId;
  final String skillName;
  final GroupStatus status;
}

class HomeStateInput {
  const HomeStateInput({
    required this.hasActiveGroups,
    required this.reportedToday,
    required this.hasHistory,
    required this.searching,
    this.matchedGroupId,
    this.pendingGroup,
    this.peopleWaiting = 0,
    this.needed = 6,
    this.queueSkillName,
    this.streak = 0,
    this.primarySkillName,
    this.teamDayStatus,
    this.teamReady = 0,
    this.teamTotal = 0,
    this.waitingNames = const [],
  });

  final bool hasActiveGroups;
  final bool reportedToday;
  final bool hasHistory;
  final bool searching;
  final String? matchedGroupId;
  final HomePendingGroup? pendingGroup;
  final int peopleWaiting;
  final int needed;
  final String? queueSkillName;
  final int streak;
  final String? primarySkillName;
  final String? teamDayStatus;
  final int teamReady;
  final int teamTotal;
  final List<String> waitingNames;
}

class HomeHeroConfig {
  const HomeHeroConfig({
    required this.badge,
    required this.title,
    required this.body,
    this.actionLabel,
    this.progress,
    this.progressLabel,
    this.artKind = HabitArtKind.focus,
  });

  final String badge;
  final String title;
  final String body;
  final String? actionLabel;
  final double? progress;
  final String? progressLabel;
  final HabitArtKind artKind;
}

class HomeStateSnapshot {
  const HomeStateSnapshot({
    required this.phase,
    required this.hero,
    this.greetingSubtitle,
    this.focusGroupId,
    this.showJourneyStrip = false,
    this.showActiveChallenges = false,
    this.showCalendar = false,
    this.showReportComposer = false,
    this.showNoGroupEmpty = false,
  });

  final HomePhase phase;
  final HomeHeroConfig hero;
  final String? greetingSubtitle;
  final String? focusGroupId;
  final bool showJourneyStrip;
  final bool showActiveChallenges;
  final bool showCalendar;
  final bool showReportComposer;
  final bool showNoGroupEmpty;
}

class HomeStateResolver {
  const HomeStateResolver._();

  static HomeStateSnapshot resolve(HomeStateInput input) {
    final skillName = input.primarySkillName ??
        input.queueSkillName ??
        input.pendingGroup?.skillName;
    final artKind = habitArtKindFor(skillName ?? 'generic');

    if (input.matchedGroupId != null && input.matchedGroupId!.isNotEmpty) {
      return HomeStateSnapshot(
        phase: HomePhase.teamMatched,
        greetingSubtitle: 'Команда собрана — осталось подтвердить участие',
        focusGroupId: input.matchedGroupId,
        hero: HomeHeroConfig(
          badge: 'Команда готова',
          title: AppCopy.teamReadyConfirm,
          body:
              'Откройте команду и подтвердите участие, чтобы начать ${AppCopy.cycleDays}.',
          actionLabel: AppCopy.confirmParticipation,
          artKind: HabitArtKind.social,
        ),
      );
    }

    if (input.searching) {
      final progress =
          input.needed > 0 ? input.peopleWaiting / input.needed : 0.0;
      return HomeStateSnapshot(
        phase: HomePhase.searchingTeam,
        greetingSubtitle: 'Ищем вашу шестёрку — можно закрыть экран',
        hero: HomeHeroConfig(
          badge: 'Поиск команды',
          title: 'Ищем вашу *шестёрку*',
          body:
              '${input.queueSkillName ?? 'Привычка'}: ${input.peopleWaiting} из ${input.needed} участников. Можно закрыть экран — поиск продолжится.',
          progress: progress,
          progressLabel: '${input.peopleWaiting}/${input.needed}',
          artKind: artKind,
        ),
      );
    }

    final pending = input.pendingGroup;
    if (pending?.status == GroupStatus.introduction) {
      return HomeStateSnapshot(
        phase: HomePhase.groupIntroduction,
        greetingSubtitle: 'Познакомьтесь с командой перед стартом цикла',
        focusGroupId: pending!.groupId,
        hero: HomeHeroConfig(
          badge: 'Знакомство',
          title: 'Познакомьтесь с командой',
          body:
              '${pending.skillName}: откройте группу, посмотрите профили и подтвердите участие.',
          actionLabel: 'Открыть группу',
          artKind: HabitArtKind.social,
        ),
      );
    }

    if (pending?.status == GroupStatus.rulesPending) {
      return HomeStateSnapshot(
        phase: HomePhase.groupRulesPending,
        greetingSubtitle: 'Осталось принять правила — и можно начинать',
        focusGroupId: pending!.groupId,
        hero: HomeHeroConfig(
          badge: 'Правила',
          title: 'Примите правила цикла',
          body:
              '${pending.skillName}: прочитайте правила команды и подтвердите готовность.',
          actionLabel: 'Открыть группу',
          artKind: artKind,
        ),
      );
    }

    if (input.hasActiveGroups) {
      if (input.reportedToday) {
        final teamComplete = input.teamDayStatus == 'complete';
        final waiting = input.waitingNames.take(2).join(', ');
        final remaining =
            (input.teamTotal - input.teamReady).clamp(0, input.teamTotal);
        return HomeStateSnapshot(
          phase: HomePhase.reportComplete,
          greetingSubtitle: teamComplete
              ? 'День закрыт всей командой'
              : 'Отчёт принят — ждём команду',
          showActiveChallenges: true,
          showCalendar: true,
          showReportComposer: true,
          hero: HomeHeroConfig(
            badge: teamComplete ? 'День закрыт' : 'Ждём команду',
            title: teamComplete
                ? 'День закрыт всей командой'
                : 'Отчёт принят',
            body: teamComplete
                ? 'Все ${input.teamTotal} отчитались — +1 Прайм каждому. Серия: ${input.streak} дн.'
                : remaining > 0
                    ? 'Ваш отчёт сохранён — серия не сгорит. Ждём ещё $remaining: ${waiting.isEmpty ? 'команду' : waiting}.'
                    : AppCopy.reportSavedStreakSafe,
            progress: input.teamTotal > 0
                ? input.teamReady / input.teamTotal
                : (input.streak / 30).clamp(0.0, 1.0),
            progressLabel: input.teamTotal > 0
                ? '${input.teamReady}/${input.teamTotal}'
                : '${input.streak} дн.',
            actionLabel: teamComplete ? null : AppCopy.nudgeTeam,
            artKind: artKind,
          ),
        );
      }

      return HomeStateSnapshot(
        phase: HomePhase.reportDue,
        greetingSubtitle: 'Сегодня ещё можно отправить отчёт',
        showActiveChallenges: true,
        showCalendar: true,
        showReportComposer: true,
        hero: HomeHeroConfig(
          badge: 'Сегодня',
          title: 'Закройте *день* вместе',
          body:
              'Сделайте действие и отправьте отчёт. День засчитается всей команде, только когда отчитаются все.',
          actionLabel: 'К отчёту',
          progress: input.teamTotal > 0
              ? input.teamReady / input.teamTotal
              : (input.streak / 30).clamp(0.0, 1.0),
          progressLabel: input.teamTotal > 0
              ? '${input.teamReady}/${input.teamTotal}'
              : 'Серия ${input.streak}',
          artKind: artKind,
        ),
      );
    }

    if (input.hasHistory) {
      return HomeStateSnapshot(
        phase: HomePhase.returningUser,
        greetingSubtitle: input.streak > 0
            ? 'Серия ${input.streak} дн. — найдите новую команду'
            : 'Вы уже проходили цикл — можно начать снова',
        showCalendar: true,
        showNoGroupEmpty: true,
        hero: HomeHeroConfig(
          badge: 'Снова в пути',
          title: 'Продолжите с *новой* командой',
          body:
              'Выберите привычку и соберите шестёрку — прогресс и Праймы сохранятся.',
          actionLabel: 'Выбрать привычку',
          artKind: HabitArtKind.focus,
        ),
      );
    }

    return HomeStateSnapshot(
      phase: HomePhase.newUser,
      greetingSubtitle: 'Первый шаг — выбрать привычку и найти команду',
      showJourneyStrip: true,
      showNoGroupEmpty: true,
      hero: HomeHeroConfig(
        badge: 'Старт',
        title: 'Ваш *путь* начинается здесь',
        body:
            'Выберите привычку и найдите команду из 6 человек. Дальше — ежедневное действие и отчёт.',
        actionLabel: 'Выбрать привычку',
        artKind: HabitArtKind.focus,
      ),
    );
  }
}
