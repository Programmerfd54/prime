import '../../design/visuals/habit_art.dart';
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
    this.pendingGroupModel,
    this.peopleWaiting = 0,
    this.needed = 6,
    this.queueSkillName,
    this.streak = 0,
    this.primarySkillName,
    this.teamDayStatus,
    this.teamReady = 0,
    this.teamTotal = 0,
    this.waitingNames = const [],
    this.currentUserId,
  });

  final bool hasActiveGroups;
  final bool reportedToday;
  final bool hasHistory;
  final bool searching;
  final String? matchedGroupId;
  final HomePendingGroup? pendingGroup;
  final GroupModel? pendingGroupModel;
  final int peopleWaiting;
  final int needed;
  final String? queueSkillName;
  final int streak;
  final String? primarySkillName;
  final String? teamDayStatus;
  final int teamReady;
  final int teamTotal;
  final List<String> waitingNames;
  final String? currentUserId;
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
    this.showWaitingCompanion = false,
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
  final bool showWaitingCompanion;
}
