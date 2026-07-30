import 'package:flutter/material.dart';

import '../../../core/home/home_state.dart';
import '../../../core/media/media_urls.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../l10n/copy.dart';
import '../../../models/direct_chat.dart';
import '../../../models/group.dart';
import '../../../models/report.dart';
import '../../../models/user.dart';
import '../../../ui/components/app_dialog.dart';
import '../../../ui/components/editorial/app_hero_module.dart';
import '../../../widgets/notification_bell_button.dart';
import '../components/prime_accent_card.dart';
import '../components/prime_content_card.dart';
import '../components/prime_social_card.dart';
import '../tokens/kit_surfaces.dart';
import '../tokens/kit_typography.dart';
import '../../../screens/dashboard/home_next_step_card.dart';
import 'home_feed_widgets.dart';
import 'home_waiting_companion.dart';

/// Visual-reset home feed — rich composition inspired by wellness references.
class GateHomePresentation extends StatelessWidget {
  const GateHomePresentation({
    super.key,
    required this.user,
    required this.dateLabel,
    required this.homeState,
    required this.streak,
    required this.primes,
    required this.successDays,
    required this.teamReady,
    required this.teamTotal,
    required this.teamPulse,
    required this.directChats,
    required this.onAvatarTap,
    required this.onPrimaryAction,
    required this.onOpenGroup,
    required this.onOpenChats,
    required this.onPrimesTap,
    this.reportComposer,
    this.recoveryBanner,
    this.calendar,
    this.waitingNames = const [],
    this.activeHabitKind,
    this.selectedMood,
    this.onMoodSelected,
    this.onOpenHabits,
    this.onNudgeTeam,
    this.showExpandedReport = false,
    this.waitingRegionSearching = 0,
    this.waitingSkillSearching = 0,
    this.waitingOnlineInPool = 0,
    this.waitingRegionLabel,
    this.waitingScopeIsRussia = false,
    this.waitingPeopleWaiting = 0,
    this.waitingNeeded = 6,
    this.waitingSkillName,
    this.onFindFriends,
  });

  final UserModel? user;
  final String dateLabel;
  final HomeStateSnapshot homeState;
  final int streak;
  final int primes;
  final int successDays;
  final int teamReady;
  final int teamTotal;
  final TeamPulseModel? teamPulse;
  final List<DirectChatSummary> directChats;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onOpenGroup;
  final VoidCallback? onOpenChats;
  final VoidCallback onPrimesTap;
  final Widget? reportComposer;
  final Widget? recoveryBanner;
  final CalendarOut? calendar;
  final List<String> waitingNames;
  final HabitArtKind? activeHabitKind;
  final String? selectedMood;
  final ValueChanged<String>? onMoodSelected;
  final VoidCallback? onOpenHabits;
  final VoidCallback? onNudgeTeam;
  final bool showExpandedReport;
  final int waitingRegionSearching;
  final int waitingSkillSearching;
  final int waitingOnlineInPool;
  final String? waitingRegionLabel;
  final bool waitingScopeIsRussia;
  final int waitingPeopleWaiting;
  final int waitingNeeded;
  final String? waitingSkillName;
  final VoidCallback? onFindFriends;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Спокойной ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name.trim() ?? '';
    final avatars = _teamAvatars();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHeader(
          greeting: 'С возвращением',
          name: name.isEmpty ? _greeting : name,
          dateLabel: dateLabel,
          streak: streak,
          photoUrl: user?.photoUrl,
          onAvatarTap: onAvatarTap,
          trailing: const NotificationBellButton(hasUnread: false),
        ),
        const SizedBox(height: AppSpacing.md),
        HomeNextStepCard(state: homeState, onPrimaryAction: onPrimaryAction),
        if (homeState.showReportComposer && reportComposer != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _DailyReportSection(
            reportComposer: reportComposer!,
            selectedMood: selectedMood,
            onMoodSelected: onMoodSelected,
            showExpandedReport: showExpandedReport,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        HomeCategoriesRow(
          activeKind: activeHabitKind,
          onSeeAll: onOpenHabits,
          onCategoryTap: (_) => onOpenHabits?.call(),
        ),
        const SizedBox(height: AppSpacing.lg),
        HomeProgressMetrics(
          streak: streak,
          primes: primes,
          successDays: successDays,
          onPrimesTap: onPrimesTap,
        ),
        if (homeState.showWaitingCompanion) ...[
          const SizedBox(height: AppSpacing.lg),
          HomeWaitingCompanion(
            skillName: waitingSkillName ?? 'Привычка',
            peopleWaiting: waitingPeopleWaiting,
            needed: waitingNeeded,
            regionSearching: waitingRegionSearching,
            skillSearching: waitingSkillSearching,
            onlineInPool: waitingOnlineInPool,
            regionLabel: waitingRegionLabel ?? 'вашем городе',
            scopeIsRussia: waitingScopeIsRussia,
            onOpenGroups: onOpenGroup,
            onOpenChats: onOpenChats,
            onFindFriends: onFindFriends,
            showFriendsCta: directChats.isEmpty,
          ),
        ],
        if (homeState.showCalendar && calendar != null) ...[
          const SizedBox(height: AppSpacing.lg),
          HomeCalendarStrip(calendar: calendar),
        ],
        if (recoveryBanner != null) ...[
          const SizedBox(height: AppSpacing.md),
          recoveryBanner!,
        ],
        if (homeState.showJourneyStrip) ...[
          const SizedBox(height: AppSpacing.md),
          const AppJourneyStrip(),
        ],
        if (teamTotal > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          HomeTeamPulseCard(
            title: 'Пульс команды',
            subtitle: teamPulse?.message ??
                '$teamReady из $teamTotal сдали отчёт сегодня',
            teamReady: teamReady,
            teamTotal: teamTotal,
            avatars: avatars,
            waitingNames: waitingNames,
            pulseStatus: teamPulse?.status,
            onTap: onOpenGroup,
            onNudge: onNudgeTeam,
          ),
        ],
        if (teamPulse != null && teamPulse!.checkIns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          HomeTeamActivityFeed(
            checkIns: teamPulse!.checkIns,
            onSeeAll: onOpenGroup,
          ),
        ],
        if (directChats.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          HomeSectionHeader(title: 'Активность'),
          const SizedBox(height: AppSpacing.sm),
          ...directChats.take(3).map(
            (chat) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: PrimeContentCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                onTap: onOpenChats,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: absolutePhotoUrl(chat.friend.photoUrl) != null
                          ? NetworkImage(absolutePhotoUrl(chat.friend.photoUrl)!)
                          : null,
                      child: chat.friend.photoUrl == null
                          ? Text(
                              chat.friend.name.isNotEmpty
                                  ? chat.friend.name[0]
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.friend.name.isNotEmpty
                                ? chat.friend.name
                                : chat.friend.nickname,
                            style: KitTypography.cardTitle.copyWith(fontSize: 15),
                          ),
                          Text(
                            chat.lastMessageBody ?? 'Нет сообщений',
                            style: KitTypography.caption.copyWith(
                              color: context.prime.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (homeState.showNoGroupEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          PrimeAccentCard(
            title: 'Начните с привычки',
            body: 'Выберите программу — мы подберём команду из шести человек.',
            actionLabel: 'Открыть каталог',
            onAction: onPrimaryAction,
            accent: KitAccent.brand,
          ),
        ],
      ],
    );
  }

  List<PrimeSocialAvatar> _teamAvatars() {
    final checkIns = teamPulse?.checkIns ?? const [];
    if (checkIns.isNotEmpty) {
      return checkIns
          .take(6)
          .map(
            (c) => PrimeSocialAvatar(
              name: c.nickname.isNotEmpty ? c.nickname : '?',
              ready: c.kind == 'ready' || c.kind == 'done',
            ),
          )
          .toList();
    }
    return List.generate(
      teamTotal.clamp(0, 6),
      (i) => PrimeSocialAvatar(
        name: String.fromCharCode(65 + i),
        ready: i < teamReady,
      ),
    );
  }
}

/// Primary daily report block — above team pulse (V6 Phase 4 hierarchy).
class _DailyReportSection extends StatelessWidget {
  const _DailyReportSection({
    required this.reportComposer,
    this.selectedMood,
    this.onMoodSelected,
    required this.showExpandedReport,
  });

  final Widget reportComposer;
  final String? selectedMood;
  final ValueChanged<String>? onMoodSelected;
  final bool showExpandedReport;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ежедневный отчёт',
            style: AppTypography.title2.copyWith(color: p.ink),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Главное действие дня — коротко зафиксируйте прогресс',
            style: AppTypography.caption.copyWith(color: p.inkSecondary),
          ),
          if (onMoodSelected != null) ...[
            const SizedBox(height: AppSpacing.md),
            HomeMoodPicker(
              selected: selectedMood,
              onSelected: onMoodSelected!,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          reportComposer,
        ],
      ),
    );
  }
}

void showGatePrimesDialog(BuildContext context) {
  showAppInfoDialog(
    context: context,
    title: AppCopy.primes,
    body: AppCopy.primesExplainer,
  );
}
