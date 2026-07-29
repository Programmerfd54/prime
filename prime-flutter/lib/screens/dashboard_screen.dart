import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../core/habits/habit_program_metadata.dart';
import '../core/home/home_state.dart';
import '../core/pending/report_queue.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/lottie_registry.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/direct_chat.dart';
import '../models/group.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/habit_art.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_skeleton.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_textarea.dart';
import '../ui/kit/presentation/gate_home_presentation.dart';
import '../ui/kit/prime_kit.dart';
import '../ui/components/dashboard/recovery_banner.dart';
import '../widgets/async_error_view.dart';
import 'dashboard/dashboard_helpers.dart';
import 'avatar_screen.dart';
import 'group_detail_screen.dart';

/// Главный экран: статистика, стик-статус, быстрый отчёт.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onOpenHabits,
    this.onOpenChats,
  });

  final VoidCallback? onOpenHabits;
  final VoidCallback? onOpenChats;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _ActiveChallenge {
  final String groupId;
  final String skillId;
  final String skillName;
  final CalendarOut? calendar;
  final TeamDayModel? teamDay;
  final TeamPulseModel? teamPulse;

  const _ActiveChallenge({
    required this.groupId,
    required this.skillId,
    required this.skillName,
    required this.calendar,
    this.teamDay,
    this.teamPulse,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  CalendarOut? _activityCalendar;
  String? _groupId;
  final List<_ActiveChallenge> _activeChallenges = [];
  Map<String, dynamic>? _pendingGroup;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _errorCorrelationId;
  final _reportCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _reportComposerKey = GlobalKey();
  List<DirectChatSummary> _directChats = [];
  late DateTime _visibleMonth;
  String? _selectedMood;
  bool _showExpandedReport = false;

  @override
  void dispose() {
    _reportCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _needsRecoveryBanner(CalendarOut? calendar, int successfulDays) {
    if (calendar == null || successfulDays <= 0) return false;
    if (calendar.currentStreak > 0) return false;
    final readyDays = calendar.days
        .where((d) => d.reported || d.completed)
        .map((d) => d.date)
        .toList();
    if (readyDays.isEmpty) return false;
    readyDays.sort((a, b) => b.compareTo(a));
    final last = readyDays.first;
    final today = calendar.today;
    return today.difference(last).inDays > 1;
  }

  Future<void> _showReportDoneCelebration({
    bool teamComplete = false,
    int teamReady = 0,
    int teamTotal = 0,
  }) async {
    if (!mounted) return;
    final title =
        teamComplete ? 'День закрыт!' : 'Отчёт принят, ждём команду';
    final body = teamComplete
        ? 'Отчёт засчитан — серия продолжается.'
        : teamTotal > 0
            ? 'Прогресс команды: $teamReady/$teamTotal. ${AppCopy.reportSavedStreakSafe}.'
            : AppCopy.reportSavedStreakSafe;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrimeLottie(
              slot: PrimeLottieSlot.success,
              width: 140,
              height: 140,
              repeat: false,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.title1),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: 'Отлично',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  bool get _reportedTodayOnActive {
    for (final challenge in _activeChallenges) {
      final calendar = challenge.calendar;
      if (calendar == null) continue;
      for (final day in calendar.days) {
        if (_sameDate(day.date, calendar.today) &&
            (day.reported || day.completed)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _load();
  }

  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _showNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _errorCorrelationId = null;
      });
    }
    final api = context.read<ApiClient>();
    unawaited(ReportQueue.instance.flush(api));
    try {
      _activityCalendar = CalendarOut.fromJson(await api.calendarAll());
      final groups = await api.listGroups();
      final allGroups = groups.cast<Map<String, dynamic>>();
      _pendingGroup = null;
      for (final group in allGroups) {
        final status = group['status'] as String?;
        if (status == 'introduction') {
          _pendingGroup = group;
          break;
        }
        if (status == 'rules_pending') {
          _pendingGroup ??= group;
        }
      }
      final active = allGroups
          .where(
            (g) => g['status'] == 'active',
          )
          .toList();
      _activeChallenges.clear();
      if (active.isNotEmpty) {
        final previousGroupId = _groupId;
        for (final group in active) {
          final parsed = GroupModel.fromJson(group);
          CalendarOut? calendar;
          try {
            calendar = CalendarOut.fromJson(await api.calendar(parsed.id));
          } catch (_) {
            calendar = null;
          }
          _activeChallenges.add(
            _ActiveChallenge(
              groupId: parsed.id,
              skillId: parsed.skillId,
              skillName: (parsed.skillName ?? parsed.name).trim().isNotEmpty
                  ? (parsed.skillName ?? parsed.name)
                  : 'Текущая привычка',
              calendar: calendar,
              teamDay: parsed.teamDay,
              teamPulse: parsed.teamPulse,
            ),
          );
        }
        final hasPreviousSelection = previousGroupId != null &&
            _activeChallenges.any(
              (challenge) => challenge.groupId == previousGroupId,
            );
        _groupId = hasPreviousSelection
            ? previousGroupId
            : _activeChallenges.first.groupId;
      } else {
        _groupId = null;
        _activeChallenges.clear();
      }
      try {
        final chats = await api.listDirectChats();
        _directChats = chats
            .map(
              (item) =>
                  DirectChatSummary.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        _directChats = [];
      }
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        _error = failure.message;
        _errorCorrelationId = failure.correlationId;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  HomePendingGroup? _pendingGroupContext() {
    final raw = _pendingGroup;
    if (raw == null) return null;
    return HomePendingGroup(
      groupId: raw['id'] as String,
      skillName: raw['skill_name'] as String? ??
          raw['name'] as String? ??
          'Команда',
      status: _groupStatusFrom(raw['status'] as String?),
    );
  }

  GroupStatus _groupStatusFrom(String? value) {
    switch (value) {
      case 'introduction':
        return GroupStatus.introduction;
      case 'rules_pending':
        return GroupStatus.rulesPending;
      case 'active':
        return GroupStatus.active;
      default:
        return GroupStatus.forming;
    }
  }

  void _openGroup(String groupId) {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupDetailScreen(groupId: groupId),
      ),
    );
  }

  void _onHomePrimaryAction(HomeStateSnapshot state) {
    switch (state.phase) {
      case HomePhase.newUser:
      case HomePhase.returningUser:
        widget.onOpenHabits?.call();
        return;
      case HomePhase.teamMatched:
      case HomePhase.groupIntroduction:
      case HomePhase.groupRulesPending:
        final groupId = state.focusGroupId;
        if (groupId != null) _openGroup(groupId);
        return;
      case HomePhase.reportDue:
        _scrollToReportComposer();
        return;
      case HomePhase.searchingTeam:
        return;
      case HomePhase.reportComplete:
        if (state.hero.actionLabel == AppCopy.nudgeTeam) {
          final groupId = _groupId ?? state.focusGroupId;
          if (groupId != null) {
            unawaited(_nudgeGroup(groupId));
          }
        }
        return;
    }
  }

  Future<void> _nudgeGroup(String groupId) async {
    try {
      final result = await context.read<ApiClient>().nudgeGroup(groupId);
      if (!mounted) return;
      final alreadyComplete = result['already_complete'] as bool? ?? false;
      showAppSnackBar(
        context,
        alreadyComplete
            ? 'День уже закрыт — все отчитались'
            : 'Напоминание отправлено команде',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    }
  }

  void _onMoodSelected(String mood) {
    setState(() {
      _selectedMood = mood;
      _showExpandedReport = true;
    });
    final prefix = switch (mood) {
      'great' => '😊 Отличный день. ',
      'good' => '🙂 Нормальный день. ',
      'okay' => '😐 Так себе. ',
      'hard' => '😔 Сложный день. ',
      _ => '',
    };
    if (_reportCtrl.text.isEmpty && prefix.isNotEmpty) {
      _reportCtrl.text = prefix;
      _reportCtrl.selection = TextSelection.collapsed(offset: prefix.length);
    }
    _scrollToReportComposer();
  }

  Future<void> _nudgeTeamFromHome() async {
    final groupId = _groupId;
    if (groupId == null) return;
    await _nudgeGroup(groupId);
  }

  void _scrollToReportComposer() {
    if (_groupId == null) return;
    final target = _reportComposerKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  Future<void> _sendReport() async {
    final text = _reportCtrl.text.trim();
    if (_groupId == null || text.isEmpty || _sending) return;
    final groupId = _groupId!;
    final wasReported = _reportedTodayOnActive;
    setState(() => _sending = true);
    Analytics.instance.checkinStarted(groupId);
    final api = context.read<ApiClient>();
    final reportPayload = {
      'group_id': _groupId,
      'content_text': text,
      'support_given': false,
    };
    try {
      final result = await api.createReport(reportPayload);
      _reportCtrl.clear();
      if (wasReported) {
        Analytics.instance.checkinEdited(groupId);
      } else {
        Analytics.instance.checkinCompleted(groupId);
      }
      final teamDayRaw = result['team_day'];
      final teamDay = teamDayRaw is Map<String, dynamic>
          ? TeamDayModel.fromJson(teamDayRaw)
          : (teamDayRaw is Map
              ? TeamDayModel.fromJson(Map<String, dynamic>.from(teamDayRaw))
              : null);
      await _load();
      if (mounted) await context.read<AuthProvider>().refreshUser();
      if (mounted && !wasReported) {
        await _showReportDoneCelebration(
          teamComplete: teamDay?.isComplete == true,
          teamReady: teamDay?.readyCount ?? 0,
          teamTotal: teamDay?.memberCount ?? 0,
        );
      }
    } catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await ReportQueue.instance.enqueueReport(reportPayload);
        _reportCtrl.clear();
        if (mounted) {
          showAppSnackBar(
            context,
            'Нет сети — отчёт сохранён и отправится при подключении',
          );
        }
      } else if (mounted) {
        showAppSnackBar(context, ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  _ActiveChallenge? get _selectedChallenge {
    if (_activeChallenges.isEmpty) return null;
    final selectedId = _groupId;
    if (selectedId == null) return _activeChallenges.first;
    for (final challenge in _activeChallenges) {
      if (challenge.groupId == selectedId) return challenge;
    }
    return _activeChallenges.first;
  }

  ({String? status, int ready, int total, List<String> waitingNames})
      _teamDayFieldsFor(_ActiveChallenge? challenge) {
    if (challenge == null) {
      return (status: null, ready: 0, total: 0, waitingNames: const []);
    }
    final teamDay = challenge.teamDay;
    final pulse = challenge.teamPulse;
    final ready = teamDay?.readyCount ?? pulse?.completedToday ?? 0;
    final total = teamDay?.memberCount ??
        pulse?.totalActive ??
        0;
    final status = teamDay?.status ??
        (pulse?.isTeamDayComplete == true
            ? 'complete'
            : pulse?.dayStatus);
    final waiting = teamDay?.waitingFor.isNotEmpty == true
        ? teamDay!.waitingFor
        : (pulse?.waitingFor ?? const <TeamWaitingMember>[]);
    final waitingNames = waiting
        .map((m) => m.displayName)
        .where((name) => name.isNotEmpty)
        .toList();
    return (
      status: status,
      ready: ready,
      total: total,
      waitingNames: waitingNames,
    );
  }

  Widget _buildReportComposer({
    required bool reportedToday,
    required HomeStateSnapshot homeState,
  }) {
    final selected = _selectedChallenge;
    final reportFormat =
        HabitProgramCatalog.metaForId(selected?.skillId)?.reportFormat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _groupId,
          decoration: const InputDecoration(
            labelText: 'Привычка для отчёта',
            prefixIcon: Icon(Icons.track_changes),
          ),
          items: [
            for (final challenge in _activeChallenges)
              DropdownMenuItem<String>(
                value: challenge.groupId,
                child: Text(
                  challenge.skillName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _sending
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _groupId = value);
                },
        ),
        if (reportFormat != null && reportFormat.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Формат: $reportFormat', style: AppTypography.caption),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppTextarea(
          controller: _reportCtrl,
          minLines: 3,
          maxLines: 5,
          hint: reportedToday
              ? 'Обновите отчёт, если нужно что-то уточнить'
              : reportFormat ?? 'Что сделал сегодня для развития привычки?',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          label: _sending
              ? 'Отправка…'
              : reportedToday
                  ? 'Обновить отчёт'
                  : 'Отправить отчёт',
          icon: Icons.send,
          loading: _sending,
          onPressed: _sending ? null : _sendReport,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final waiting = context.watch<WaitingRoomPoller>();
    if (_loading && _activityCalendar == null && _activeChallenges.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg - 4,
              AppSpacing.md,
              AppSpacing.lg - 4,
              AppSpacing.bottomNavClearance,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(const [
                AppSkeleton(height: 36, width: 220),
                SizedBox(height: AppSpacing.md),
                AppSkeleton(height: 88),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: AppSkeleton(height: 72)),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(child: AppSkeleton(height: 72)),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                AppSkeleton(height: 72),
              ]),
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        correlationId: _errorCorrelationId,
        onRetry: _load,
      );
    }

    final hasActive = _activeChallenges.isNotEmpty;
    final searching = waiting.inQueue && waiting.matchedGroupId == null;
    final hasHistory = (user?.successfulDays ?? 0) > 0 ||
        (_activityCalendar?.currentStreak ?? 0) > 0;
    final reportedToday = _reportedTodayOnActive;
    final primary = _selectedChallenge;
    final teamDay = _teamDayFieldsFor(primary);
    final homeState = HomeStateResolver.resolve(
      HomeStateInput(
        hasActiveGroups: hasActive,
        reportedToday: reportedToday,
        hasHistory: hasHistory,
        searching: searching,
        matchedGroupId: waiting.matchedGroupId,
        pendingGroup: _pendingGroupContext(),
        peopleWaiting: waiting.status?.peopleWaiting ?? 0,
        needed: waiting.status?.needed ?? 6,
        queueSkillName: waiting.status?.skillName,
        streak: _activityCalendar?.currentStreak ?? 0,
        primarySkillName: primary?.skillName,
        teamDayStatus: teamDay.status,
        teamReady: teamDay.ready,
        teamTotal: teamDay.total,
        waitingNames: teamDay.waitingNames,
      ),
    );
    final showRecovery = _needsRecoveryBanner(
      _activityCalendar,
      user?.successfulDays ?? 0,
    );

    const feedPadding = EdgeInsets.fromLTRB(
      AppSpacing.lg - 4,
      AppSpacing.md,
      AppSpacing.lg - 4,
      KitLayout.navBottomClearance,
    );

    return AmbientCanvas(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: feedPadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  GateHomePresentation(
                    user: user,
                    dateLabel: dashboardTodayLabel(),
                    homeState: homeState,
                    streak: _activityCalendar?.currentStreak ?? 0,
                    primes: user?.primePoints ?? 0,
                    successDays: user?.successfulDays ?? 0,
                    teamReady: teamDay.ready,
                    teamTotal: teamDay.total,
                    teamPulse: primary?.teamPulse,
                    directChats: _directChats,
                    calendar: _activityCalendar,
                    waitingNames: teamDay.waitingNames,
                    activeHabitKind: primary != null
                        ? habitArtKindFor(primary.skillName)
                        : null,
                    selectedMood: _selectedMood,
                    onMoodSelected: homeState.showReportComposer ? _onMoodSelected : null,
                    onOpenHabits: widget.onOpenHabits,
                    onNudgeTeam: _nudgeTeamFromHome,
                    showExpandedReport: _showExpandedReport,
                    onAvatarTap: () {
                      Navigator.of(context).push(
                        PrimeRoute.sharedAxis(builder: (_) => const AvatarScreen()),
                      );
                    },
                    onPrimaryAction: () => _onHomePrimaryAction(homeState),
                    onOpenGroup: primary != null
                        ? () => _openGroup(primary.groupId)
                        : null,
                    onOpenChats: widget.onOpenChats,
                    onPrimesTap: () => showGatePrimesDialog(context),
                    recoveryBanner: showRecovery
                        ? RecoveryBanner(
                            onAction: homeState.showReportComposer
                                ? _scrollToReportComposer
                                : widget.onOpenHabits,
                          )
                        : null,
                    reportComposer: homeState.showReportComposer && _groupId != null
                        ? KeyedSubtree(
                            key: _reportComposerKey,
                            child: _buildReportComposer(
                              reportedToday: reportedToday,
                              homeState: homeState,
                            ),
                          )
                        : null,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
