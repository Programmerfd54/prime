import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/analytics/analytics.dart';
import '../core/groups/group_member_today_status.dart';
import '../core/groups/group_prep_state.dart';
import '../ui/components/phase_celebration.dart';
import '../core/habits/habit_program_metadata.dart';
import '../core/errors/failure_mapper.dart';
import '../core/pending/report_queue.dart';
import '../core/sync/realtime_client.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../models/group.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/kit/components/prime_content_card.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/editorial/app_habit_coach_panel.dart';
import '../ui/components/editorial/app_group_prep_chat.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/editorial/app_weekly_team_challenge.dart';
import '../ui/components/editorial/app_group_recap.dart';
import '../ui/components/editorial/app_group_today_hub.dart';
import '../ui/components/app_header.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_textarea.dart';
import '../ui/states/app_loading_state.dart';
import '../widgets/async_error_view.dart';
import 'cycle_transformation_screen.dart';
import 'group_chat_screen.dart';
import 'public_profile_screen.dart';

/// Детальная страница группы: участники, правила, голосование, отчёты.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupModel? _group;
  CalendarDay? _todayReport;
  bool _loading = true;
  bool _actionInProgress = false;
  bool _checkInSending = false;
  String? _error;
  String? _errorCorrelationId;
  bool _cycleCompletedEmitted = false;
  String? _lastPrepPhaseKey;
  final _reportCtrl = TextEditingController();
  RealtimeClient? _realtime;
  Timer? _prepPollTimer;
  _ActiveGroupTab _activeTab = _ActiveGroupTab.today;

  @override
  void dispose() {
    _prepPollTimer?.cancel();
    _realtime?.removeGroupUpdateListener(_onGroupUpdate);
    _realtime?.removeListener(_onRealtimeStateChanged);
    _reportCtrl.dispose();
    super.dispose();
  }

  bool _sendingReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _realtime = context.read<RealtimeClient>();
      _realtime!.addGroupUpdateListener(_onGroupUpdate);
      _realtime!.addListener(_onRealtimeStateChanged);
      _syncPrepPoll(_group);
    });
    _loadInitial();
  }

  void _onGroupUpdate(GroupUpdatePush push) {
    if (push.groupId != widget.groupId || !mounted) return;
    if (push.reason == 'milestone_unlocked' && push.milestoneId != null) {
      unawaited(_showMilestoneCelebration(push.milestoneId!));
    }
    final local = _group;
    final phaseAdvanced = push.phase == 'active' &&
        local != null &&
        local.status != GroupStatus.active;
    final revisionNewer = local == null ||
        push.revision <= 0 ||
        push.revision > local.revision;
    if (!phaseAdvanced &&
        !revisionNewer &&
        push.reason != 'milestone_unlocked' &&
        push.reason != 'cycle_started') {
      return;
    }
    unawaited(_refreshGroup(silent: true));
  }

  void _onRealtimeStateChanged() {
    if (!mounted) return;
    _syncPrepPoll(_group);
  }

  void _syncPrepPoll(GroupModel? group) {
    _prepPollTimer?.cancel();
    if (group == null ||
        (group.status != GroupStatus.introduction &&
            group.status != GroupStatus.rulesPending)) {
      return;
    }
    // Keep polling during prep even when SSE is connected — mobile reconnects
    // and missed group_update events are common while waiting on others.
    final interval = _realtime?.isSseConnected == true
        ? const Duration(seconds: 4)
        : const Duration(seconds: 3);
    _prepPollTimer = Timer.periodic(interval, (_) {
      if (mounted) unawaited(_refreshGroup(silent: true));
    });
  }

  Future<void> _loadInitial() => _refreshGroup(silent: false);

  Future<void> _refreshGroup({required bool silent}) async {
    if (mounted && !silent) {
      setState(() {
        _loading = true;
        _error = null;
        _errorCorrelationId = null;
      });
    }
    final api = context.read<ApiClient>();
    unawaited(ReportQueue.instance.flush(api));
    try {
      final group = GroupModel.fromJson(await api.getGroup(widget.groupId));
      final todayReport = group.myTodayReport;
      if (mounted) {
        final previous = _group;
        setState(() {
          _group = group;
          _todayReport = todayReport;
          if (!silent) _loading = false;
        });
        _maybeCelebratePhaseTransition(previous, group);
        _syncPrepPoll(group);
        unawaited(_maybeOpenCycleTransformation(group));
      } else {
        _group = group;
        _todayReport = todayReport;
      }
      if (group.status == GroupStatus.completed && !_cycleCompletedEmitted) {
        _cycleCompletedEmitted = true;
        Analytics.instance.cycleCompleted(
          groupId: group.id,
          skillId: group.skillId,
        );
      }
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        setState(() {
          _error = failure.message;
          _errorCorrelationId = failure.correlationId;
          if (!silent) _loading = false;
        });
      }
    }
  }

  Future<void> _load() => _refreshGroup(silent: false);

  DateTime? _supportCooldownUntil;

  void _maybeCelebratePhaseTransition(GroupModel? before, GroupModel after) {
    if (before == null) return;
    final key = '${after.status.name}:${after.revision}';
    if (_lastPrepPhaseKey == key) return;
    final introToRules = before.status == GroupStatus.introduction &&
        after.status == GroupStatus.rulesPending;
    final rulesToActive = before.status == GroupStatus.rulesPending &&
        after.status == GroupStatus.active;
    if ((introToRules || rulesToActive) && mounted) {
      unawaited(
        showPhaseCelebration(
          context,
          kind: introToRules
              ? PhaseCelebrationKind.introToRules
              : PhaseCelebrationKind.rulesToActive,
        ),
      );
    }
    _lastPrepPhaseKey = key;
  }

  void _applyGroupJson(Map<String, dynamic> json) {
    if (!mounted) return;
    final previous = _group;
    final next = GroupModel.fromJson(json);
    setState(() => _group = next);
    _maybeCelebratePhaseTransition(previous, next);
    _syncPrepPoll(_group);
  }

  GroupModel _optimisticConfirm(GroupModel group, {required bool rules}) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return group;
    final members = group.members.map((member) {
      if (member.userId != userId) return member;
      return member.copyWith(
        confirmedParticipation: rules ? member.confirmedParticipation : true,
        acceptedRules: rules ? true : member.acceptedRules,
      );
    }).toList();
    return group.copyWith(members: members);
  }

  Future<void> _confirm() async {
    final previous = _group;
    if (previous != null) {
      setState(() => _group = _optimisticConfirm(previous, rules: false));
    }
    await _runGroupAction(
      () => context.read<ApiClient>().confirmParticipation(widget.groupId),
      onSuccess: () => Analytics.instance.teamJoinConfirmed(widget.groupId),
      rollback: previous,
    );
  }

  Future<void> _acceptRules() async {
    final previous = _group;
    if (previous != null) {
      setState(() => _group = _optimisticConfirm(previous, rules: true));
    }
    await _runGroupAction(
      () => context.read<ApiClient>().acceptRules(widget.groupId),
      rollback: previous,
    );
  }

  Future<void> _changeGroup() async {
    final agreed = await showAppConfirmDialog(
      context: context,
      title: 'Сменить команду?',
      body: 'Вы выйдете из этой команды, а поиск по привычке начнётся заново. '
          'Остальным участникам сразу покажем, что ищем замену.',
      confirmLabel: 'Сменить команду',
      cancelLabel: 'Остаться',
      destructive: true,
    );
    if (agreed != true || !mounted || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final payload =
          await context.read<ApiClient>().changeIntroGroup(widget.groupId);
      if (!mounted) return;
      final waiting = WaitingRoomStatus.fromJson(payload);
      final poller = context.read<WaitingRoomPoller>();
      poller.applySnapshot(waiting);
      poller.start(immediate: false);
      showAppSnackBar(context, 'Новый поиск уже начался');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _vote(String choice) async {
    final confirmation = switch (choice) {
      'continue_together' => 'Вы выбрали продолжить этой командой',
      'new_skill' => 'Вы выбрали новую привычку',
      'harder' => 'Вы выбрали более сложный цикл',
      'recovery' => 'Неделя восстановления выбрана',
      _ => 'Выбор сохранён',
    };
    await _runGroupAction(
      () => context.read<ApiClient>().vote(widget.groupId, choice),
      onSuccess: () => showAppSnackBar(context, confirmation),
    );
  }

  Future<void> _checkIn(String kind) async {
    if (_checkInSending) return;
    setState(() => _checkInSending = true);
    try {
      final payload =
          await context.read<ApiClient>().groupCheckIn(widget.groupId, kind);
      _applyGroupJson(payload);
    } catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await ReportQueue.instance.enqueueCheckIn(
          groupId: widget.groupId,
          kind: kind,
        );
        if (mounted) {
          showAppSnackBar(
              context, 'Нет сети — отправим отметку при подключении');
        }
      } else if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _checkInSending = false);
    }
  }

  Future<void> _support(MemberModel member) async {
    if (_actionInProgress) return;
    if (_supportCooldownUntil != null &&
        DateTime.now().isBefore(_supportCooldownUntil!)) {
      final minutes = _supportCooldownUntil!.difference(DateTime.now()).inMinutes;
      if (mounted) {
        showAppSnackBar(
          context,
          'Поддержку можно отправить через ${minutes.clamp(1, 10)} мин',
        );
      }
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      final payload = await context.read<ApiClient>().supportGroupMember(
            groupId: widget.groupId,
            targetUserId: member.userId,
          );
      _applyGroupJson(payload);
      if (mounted) {
        final nickname = member.profile?.nickname ?? '';
        showAppSnackBar(
          context,
          nickname.isEmpty
              ? 'Поддержка отправлена'
              : 'Поддержка для @$nickname отправлена',
        );
      }
    } catch (e) {
      final failure = FailureMapper.from(e);
      if (failure.statusCode == 429 && mounted) {
        setState(
          () => _supportCooldownUntil =
              DateTime.now().add(const Duration(minutes: 10)),
        );
      }
      if (mounted) showAppSnackBar(context, failure.message);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _reactToReport(String messageId, String emoji) async {
    try {
      await context.read<ApiClient>().chatToggleReaction(messageId, emoji);
      if (mounted) showAppSnackBar(context, 'Реакция отправлена');
    } catch (e) {
      if (mounted) showAppSnackBar(context, FailureMapper.from(e).message);
    }
  }

  Future<void> _maybeOpenCycleTransformation(GroupModel group) async {
    if (group.status != GroupStatus.voting &&
        group.status != GroupStatus.completed) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'cycle_transform_seen_${group.id}';
    if (prefs.getBool(key) == true || !mounted) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CycleTransformationScreen(
          group: group,
          onContinueTogether: () {
            Navigator.of(context).pop();
            unawaited(_vote('continue_together'));
          },
          onNewSkill: () {
            Navigator.of(context).pop();
            unawaited(_vote('new_skill'));
          },
          onHarder: () {
            Navigator.of(context).pop();
            unawaited(_vote('harder'));
          },
          onRecovery: () {
            Navigator.of(context).pop();
            unawaited(_vote('recovery'));
          },
        ),
      ),
    );
  }

  Future<void> _showMilestoneCelebration(String milestoneId) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'milestone_seen_${widget.groupId}_$milestoneId';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    await showPhaseCelebration(
      context,
      kind: PhaseCelebrationKind.teamDayClosed,
    );
  }

  Future<void> _runGroupAction(
    Future<Map<String, dynamic>> Function() action, {
    VoidCallback? onSuccess,
    GroupModel? rollback,
  }) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final payload = await action();
      _applyGroupJson(payload);
      onSuccess?.call();
    } catch (e) {
      if (rollback != null && mounted) {
        setState(() => _group = rollback);
      }
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<bool> _sendReport(List<Map<String, dynamic>> attachments) async {
    final text = _reportCtrl.text.trim();
    if ((text.isEmpty && attachments.isEmpty) || _sendingReport) return false;
    final wasAlreadyReported = _todayReport?.reported == true;
    setState(() => _sendingReport = true);
    final api = context.read<ApiClient>();
    final reportPayload = {
      'group_id': widget.groupId,
      'content_text': text,
      'status': 'ready',
      'attachments': attachments,
      'support_given': false,
    };
    try {
      await api.createReport(reportPayload);
      _reportCtrl.clear();
      if (wasAlreadyReported) {
        Analytics.instance.checkinEdited(widget.groupId);
      } else {
        Analytics.instance.checkinCompleted(widget.groupId);
      }
      if (mounted) {
        showAppSnackBar(
          context,
          wasAlreadyReported ? 'Отчёт обновлён!' : 'Отчёт отправлен!',
        );
        await context.read<AuthProvider>().refreshUser();
        await _refreshGroup(silent: true);
      }
      return true;
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
        return true;
      }
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingReport = false);
    }
  }

  Future<void> _showReportSheet() async {
    final existingReport = _todayReport;
    final editing = existingReport?.reported == true;
    _reportCtrl.text = editing ? existingReport?.contentText ?? '' : '';
    Analytics.instance.checkinStarted(widget.groupId);
    await showAppBottomSheet<void>(
      context: context,
      child: _ReportSheet(
        groupId: widget.groupId,
        skillId: _group?.skillId,
        controller: _reportCtrl,
        editing: editing,
        initialAttachments: editing
            ? existingReport?.attachments ?? const <Map<String, dynamic>>[]
            : const <Map<String, dynamic>>[],
        sending: _sendingReport,
        onSend: _sendReport,
      ),
    );
  }

  void _openChat(GroupModel group) {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupChatScreen(
          groupId: group.id,
          groupName: group.skillName ?? group.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: const AppLoadingState(),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: AsyncErrorView(
          message: _error!,
          correlationId: _errorCorrelationId,
          onRetry: _load,
        ),
      );
    }
    final g = _group;
    if (g == null) {
      return Scaffold(
        appBar: buildAppBackBar(context, title: 'Группа'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PrimeContentCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: context.prime.inkMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Группа не найдена',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSerif.copyWith(
                      color: context.prime.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Возможно, ссылка устарела или доступ закрыт.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary.copyWith(
                      color: context.prime.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final prep = GroupPrepStateResolver.resolve(
      group: g,
      currentUserId: currentUserId,
      onOpenChat: () => _openChat(g),
    );
    final showPrepChat = g.status == GroupStatus.introduction ||
        g.status == GroupStatus.rulesPending;
    final memberStatusPhase = g.status == GroupStatus.rulesPending
        ? GroupStatus.rulesPending
        : GroupStatus.introduction;

    return Scaffold(
      backgroundColor: ProfileSurfaces.canvas,
      appBar: buildAppBackBar(context, title: g.name),
      body: AmbientCanvas(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitial,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  children: [
                    AppGroupDetailHero(group: g),
                    const SizedBox(height: AppSpacing.md),
                    if (g.status == GroupStatus.introduction) ...[
                      AppGroupIntroPanel(
                        group: g,
                        onOpenProfile: (member) {
                          final p = member.profile;
                          if (p == null) return;
                          Navigator.of(context).push(
                            PrimeRoute.sharedAxis(
                              builder: (_) => PublicProfileScreen(
                                profile: p,
                                reportStatus: member.reportStatus,
                                acceptedRules: member.acceptedRules,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        prep.title,
                        textAlign: TextAlign.center,
                        style: AppTypography.title2,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        prep.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppPrimaryButton(
                        label: prep.primaryLabel,
                        icon: Icons.check_circle_outline,
                        loading: _actionInProgress,
                        success:
                            prep.phase == GroupPrepPhase.waitingOthersConfirm,
                        onPressed: prep.primaryEnabled &&
                                !_actionInProgress &&
                                prep.phase == GroupPrepPhase.teamGathered
                            ? _confirm
                            : null,
                      ),
                      if (prep.showSecondaryChangeGroup) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppSecondaryButton(
                          label: 'Сменить группу',
                          onPressed: _actionInProgress ? null : _changeGroup,
                        ),
                      ],
                      if (prep.secondaryLabel != null &&
                          prep.onSecondary != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppSecondaryButton(
                          label: prep.secondaryLabel!,
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: prep.onSecondary,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (g.status == GroupStatus.rulesPending) ...[
                      const AppGroupRulesPanel(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        prep.title,
                        textAlign: TextAlign.center,
                        style: AppTypography.title2,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        prep.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppPrimaryButton(
                        label: prep.primaryLabel,
                        icon: Icons.verified_user_outlined,
                        loading: _actionInProgress,
                        success: prep.phase == GroupPrepPhase.waitingOthersPact,
                        onPressed: prep.primaryEnabled &&
                                !_actionInProgress &&
                                prep.phase == GroupPrepPhase.readyForPact
                            ? _acceptRules
                            : null,
                      ),
                      if (prep.showSecondaryChangeGroup) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppSecondaryButton(
                          label: 'Сменить группу',
                          onPressed: _actionInProgress ? null : _changeGroup,
                        ),
                      ],
                      if (prep.secondaryLabel != null &&
                          prep.onSecondary != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppSecondaryButton(
                          label: prep.secondaryLabel!,
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: prep.onSecondary,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (g.status == GroupStatus.active) ...[
                      _ActiveGroupTabSwitch(
                        value: _activeTab,
                        onChanged: (value) =>
                            setState(() => _activeTab = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_activeTab == _ActiveGroupTab.today) ...[
                        AppGroupTodayHub(
                          group: g,
                          currentUserId: currentUserId,
                          reportSending: _sendingReport,
                          checkInSending: _checkInSending,
                          onReport: _showReportSheet,
                          onCheckIn: _checkIn,
                          onSupport: _support,
                          onOpenChat: () => _openChat(g),
                          onShowProgress: () => setState(
                            () => _activeTab = _ActiveGroupTab.progress,
                          ),
                          onReaction: _reactToReport,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppHabitCoachPanel(skillId: g.skillId),
                      ],
                      if (_activeTab == _ActiveGroupTab.team) ...[
                        _ActiveTeamPanel(
                          group: g,
                          currentUserId: context.watch<AuthProvider>().user?.id,
                          onOpenChat: () => _openChat(g),
                          onOpenProfile: (member) {
                            final profile = member.profile;
                            if (profile == null) return;
                            Navigator.of(context).push(
                              PrimeRoute.sharedAxis(
                                builder: (_) => PublicProfileScreen(
                                  profile: profile,
                                  reportStatus: member.reportStatus,
                                  acceptedRules: member.acceptedRules,
                                ),
                              ),
                            );
                          },
                          onSupport: _support,
                        ),
                      ],
                      if (_activeTab == _ActiveGroupTab.progress) ...[
                        if (g.personalResult != null) ...[
                          AppPersonalImpactPanel(
                            result: g.personalResult!,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AppWeeklyTeamChallengeCard(group: g),
                        if (g.teamRecap != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppGroupRecapPanel(recap: g.teamRecap!),
                        ],
                        if (g.teamMilestones != null &&
                            g.teamMilestones!.items.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppGroupMilestonesPanel(
                            milestones: g.teamMilestones!,
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (g.status == GroupStatus.completed) ...[
                      AppGroupCycleCompletionPanel(
                        group: g,
                        onContinueTogether: () => _vote('continue_together'),
                        onNewSkill: () => _vote('new_skill'),
                        onHarder: () => _vote('harder'),
                        onRecovery: () => _vote('recovery'),
                      ),
                      if (g.personalResult != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppPersonalImpactPanel(result: g.personalResult!),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (g.status == GroupStatus.voting) ...[
                      AppGroupVotingPanel(
                        onContinueTogether: () => _vote('continue_together'),
                        onNewSkill: () => _vote('new_skill'),
                        onHarder: () => _vote('harder'),
                        onRecovery: () => _vote('recovery'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (g.status != GroupStatus.active &&
                        g.status != GroupStatus.introduction) ...[
                      Text(
                        'Участники (${g.membersCount}/${g.maxMembers})',
                        style: AppTypography.titleSerif,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...g.members.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppGroupMemberRow(
                            member: m,
                            statusPhase:
                                showPrepChat ? memberStatusPhase : null,
                            onTap: m.profile == null
                                ? null
                                : () => Navigator.of(context).push(
                                      PrimeRoute.sharedAxis(
                                        builder: (_) => PublicProfileScreen(
                                          profile: m.profile!,
                                          reportStatus: m.reportStatus,
                                          acceptedRules: m.acceptedRules,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showPrepChat)
              AppGroupPrepChat(
                groupId: g.id,
                members: g.members,
              ),
          ],
        ),
      ),
    );
  }
}

enum _ActiveGroupTab { today, team, progress }

class _ActiveGroupTabSwitch extends StatelessWidget {
  const _ActiveGroupTabSwitch({
    required this.value,
    required this.onChanged,
  });

  final _ActiveGroupTab value;
  final ValueChanged<_ActiveGroupTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ActiveTabButton(
            label: 'Сегодня',
            icon: Icons.today_outlined,
            selected: value == _ActiveGroupTab.today,
            onTap: () => onChanged(_ActiveGroupTab.today),
          ),
          _ActiveTabButton(
            label: 'Команда',
            icon: Icons.groups_2_outlined,
            selected: value == _ActiveGroupTab.team,
            onTap: () => onChanged(_ActiveGroupTab.team),
          ),
          _ActiveTabButton(
            label: 'Прогресс',
            icon: Icons.insights_outlined,
            selected: value == _ActiveGroupTab.progress,
            onTap: () => onChanged(_ActiveGroupTab.progress),
          ),
        ],
      ),
    );
  }
}

class _ActiveTabButton extends StatelessWidget {
  const _ActiveTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: selected
                  ? Border.all(
                      color: AppColors.primarySoft.withValues(alpha: 0.45),
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppColors.primarySoft
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTeamPanel extends StatelessWidget {
  const _ActiveTeamPanel({
    required this.group,
    required this.currentUserId,
    required this.onOpenChat,
    required this.onOpenProfile,
    required this.onSupport,
  });

  final GroupModel group;
  final String? currentUserId;
  final VoidCallback onOpenChat;
  final ValueChanged<MemberModel> onOpenProfile;
  final ValueChanged<MemberModel> onSupport;

  @override
  Widget build(BuildContext context) {
    final needsSupport = group.members.where((member) {
      final status = GroupMemberTodayStatus.resolve(member);
      return status.needsSupport;
    });
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ваша команда сегодня', style: AppTypography.title1),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Статусы обновляются онлайн. Поддержка появляется в общем чате.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final member in group.members) ...[
            AppGroupMemberRow(
              member: member,
              onTap:
                  member.profile == null ? null : () => onOpenProfile(member),
            ),
            if (member.userId != currentUserId &&
                needsSupport.contains(member)) ...[
              const SizedBox(height: AppSpacing.xxs),
              AppSecondaryButton(
                label: 'Поддержать @${member.profile?.nickname ?? 'участника'}',
                icon: Icons.favorite_outline_rounded,
                onPressed: () => onSupport(member),
              ),
            ],
            if (member != group.members.last)
              const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Открыть чат команды',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: onOpenChat,
          ),
        ],
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final String groupId;
  final String? skillId;
  final TextEditingController controller;
  final bool editing;
  final List<Map<String, dynamic>> initialAttachments;
  final bool sending;
  final Future<bool> Function(List<Map<String, dynamic>> attachments) onSend;

  const _ReportSheet({
    required this.groupId,
    this.skillId,
    required this.controller,
    required this.editing,
    required this.initialAttachments,
    required this.sending,
    required this.onSend,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  bool _hasText = false;
  bool _sending = false;
  bool _uploading = false;
  final _picker = ImagePicker();
  final List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
    _attachments.addAll(
      widget.initialAttachments.map((item) => {...item, 'existing': true}),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  Future<void> _send() async {
    if ((!_hasText && _attachments.isEmpty) ||
        _sending ||
        _uploading ||
        widget.sending) {
      return;
    }
    setState(() => _sending = true);
    final sent = await widget.onSend(List.unmodifiable(_attachments));
    if (mounted) setState(() => _sending = false);
    if (sent && mounted) Navigator.of(context).pop();
  }

  Future<void> _pick(String mediaType) async {
    if (kIsWeb && mediaType != 'image') {
      showAppSnackBar(
        context,
        'В web-версии отчёты пока можно отправлять текстом и фото',
      );
      return;
    }
    XFile? selected;
    if (mediaType == 'image') {
      selected = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
    } else if (mediaType == 'video') {
      selected = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      selected = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
    }
    if (selected == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded = await context
          .read<ApiClient>()
          .reportUploadMedia(widget.groupId, File(selected.path));
      if (mounted) {
        setState(() {
          _attachments.add({...uploaded, 'media_type': mediaType});
        });
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentSurface.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: AppColors.primarySoft,
                    size: AppIconSizes.sm,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.editing ? 'Поправить отчёт' : 'Отчёт за сегодня',
                    style: AppTypography.title2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (HabitProgramCatalog.metaForId(widget.skillId)
                case final meta?) ...[
              Text(
                'Подсказка: ${meta.reportTips.textTemplate}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppTextarea(
              controller: widget.controller,
              hint: HabitProgramCatalog.metaForId(widget.skillId)
                      ?.reportTips
                      .textTemplate ??
                  'Что ты сделал сегодня по этой привычке?',
              minLines: 4,
              maxLines: 7,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: 'Фото',
                    icon: Icons.photo_outlined,
                    onPressed: _uploading ? null : () => _pick('image'),
                  ),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Видео',
                      icon: Icons.videocam_outlined,
                      onPressed: _uploading ? null : () => _pick('video'),
                    ),
                  ),
                ],
              ],
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: AppSpacing.xs),
              AppSecondaryButton(
                label: 'Записать видеокружок',
                icon: Icons.circle_outlined,
                onPressed: _uploading ? null : () => _pick('video_note'),
              ),
            ],
            if (_uploading) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.elevatedSurface,
              ),
            ],
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: _attachments.asMap().entries.map((entry) {
                  final type = entry.value['media_type'];
                  return InputChip(
                    label: Text(
                      type == 'image'
                          ? 'Фото'
                          : type == 'video'
                              ? 'Видео'
                              : 'Видеокружок',
                      style: AppTypography.caption,
                    ),
                    onDeleted: _sending
                        ? null
                        : () => setState(
                              () => _attachments.removeAt(entry.key),
                            ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: _sending || widget.sending
                  ? 'Отправка...'
                  : widget.editing
                      ? 'Сохранить правку'
                      : 'Отправить отчёт',
              icon: Icons.send,
              loading: _sending || widget.sending,
              onPressed: (_hasText || _attachments.isNotEmpty) &&
                      !_sending &&
                      !_uploading &&
                      !widget.sending
                  ? _send
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
