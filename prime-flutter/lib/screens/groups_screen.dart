import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../core/groups/group_navigation.dart';
import '../core/groups/group_prep_state.dart';
import '../core/groups/team_day_presentation.dart';
import '../core/notifications/native_push_service.dart';
import '../core/sync/waiting_room_poller.dart';
import '../ui/components/app_push_degraded_banner.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../ui/kit/tokens/kit_layout.dart';
import '../ui/kit/presentation/gate_groups_active_presentation.dart';
import '../ui/kit/presentation/gate_groups_presentation.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/group.dart';
import '../models/skill.dart';
import '../providers/auth_provider.dart';
import '../screens/group_detail_screen.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/habit_art.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_skeleton.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/editorial/app_team_formation.dart';
import '../ui/components/groups/app_early_start_banner.dart';
import '../ui/components/groups/invite_friends_sheet.dart';
import '../ui/components/profile/about_before_team_sheet.dart';
import '../ui/components/profile/rhythm_support_sheet.dart';
import '../widgets/async_error_view.dart';

class GroupsScreen extends StatefulWidget {
  final SkillModel? preselectedSkill;
  final int refreshToken;
  final bool preferSearchTab;

  const GroupsScreen({
    super.key,
    this.preselectedSkill,
    this.refreshToken = 0,
    this.preferSearchTab = false,
  });

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel> _groups = [];
  WaitingRoomStatus? _waitingRoom;
  WaitingRoomStats? _waitingRoomStats;
  bool _loading = true;
  bool _joining = false;
  bool _stopping = false;
  bool _expanding = false;
  bool _assembling = false;
  bool _startingEarlyStart = false;
  String? _error;
  String? _errorCorrelationId;
  String? _handledMatchedGroupId;
  WaitingRoomPoller? _poller;
  _GroupsMode _mode = _GroupsMode.active;
  bool _membershipInconsistent = false;

  @override
  void initState() {
    super.initState();
    if (widget.preferSearchTab) {
      _mode = _GroupsMode.search;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _poller = context.read<WaitingRoomPoller>();
      _poller!.addListener(_onPollerUpdate);
      _load();
    });
  }

  @override
  void dispose() {
    _poller?.removeListener(_onPollerUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GroupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferSearchTab != widget.preferSearchTab &&
        widget.preferSearchTab) {
      _mode = _GroupsMode.search;
    } else if (oldWidget.preferSearchTab && !widget.preferSearchTab) {
      _mode = _GroupsMode.active;
    }
    if (oldWidget.preselectedSkill?.id != widget.preselectedSkill?.id ||
        oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  void _onPollerUpdate() {
    final poller = _poller;
    if (poller == null || !mounted) return;
    final status = poller.status;
    if (status != null) {
      setState(() {
        _waitingRoom = status;
        _waitingRoomStats = poller.stats;
      });
      // Do NOT call poller.start() here — refresh() already notifies, and
      // start(immediate) would create an infinite request loop.
    }
    final matchedId = poller.matchedGroupId;
    if (matchedId != null &&
        matchedId.isNotEmpty &&
        matchedId != _handledMatchedGroupId) {
      _handledMatchedGroupId = matchedId;
      unawaited(_load());
    }
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
    final poller = context.read<WaitingRoomPoller>();
    try {
      final overview = await api.groupsOverview(forceRefresh: true);
      final list = overview['groups'] as List<dynamic>? ?? const [];
      _groups = list
          .map((j) => GroupModel.fromJson(j as Map<String, dynamic>))
          .toList();
      _waitingRoom = WaitingRoomStatus.fromJson(
        overview['waiting_room'] as Map<String, dynamic>? ?? const {},
      );
      poller.applySnapshot(_waitingRoom!);
      _waitingRoomStats = poller.stats;
      _membershipInconsistent = overview['membership_consistent'] != true;
      if (_waitingRoom?.inQueue == true ||
          (_waitingRoom?.queues.isNotEmpty ?? false)) {
        poller.start(immediate: false);
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

  Future<void> _startSearch() async {
    if (widget.preselectedSkill == null) return;
    final user = context.read<AuthProvider>().user;
    final region = user?.regionName ?? user?.city ?? 'ваша область';
    final confirmed = await showAppBottomSheet<bool>(
      context: context,
      child: Builder(
        builder: (sheetContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Перед поиском команды',
                  style: AppTypography.title1,
                ),
                const SizedBox(height: AppSpacing.md),
                const _PreSearchBullet(
                  text:
                      'Цикл — ${AppCopy.cycleDays}: ежедневное действие и ${AppCopy.report}.',
                ),
                const _PreSearchBullet(
                  text: 'Каждый день нужно отчитываться в команде.',
                ),
                _PreSearchBullet(
                  text: 'Сначала ищем в регионе: $region.',
                ),
                const _PreSearchBullet(
                  text:
                      'Поиск можно остановить в любой момент, пока команда не собрана.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: AppCopy.findTeam,
                  icon: Icons.person_search,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSecondaryButton(
                  label: AppCopy.cancel,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;

    Analytics.instance.teamSearchConfigured(
      skillId: widget.preselectedSkill!.id,
      allowOtherRegions: false,
    );
    setState(() => _joining = true);
    try {
      final result = await context
          .read<ApiClient>()
          .joinWaitingRoom(widget.preselectedSkill!.id);
      if (!mounted) return;
      setState(() {
        _waitingRoom = WaitingRoomStatus.fromJson(result);
        _mode = _GroupsMode.search;
      });
      context.read<WaitingRoomPoller>().start();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _confirmEarlyStart(WaitingRoomStatus status) async {
    if (_startingEarlyStart) return;
    final skillLabel = status.skillName ?? status.skillId ?? 'привычку';
    final agreed = await showAppConfirmDialog(
      context: context,
      title: 'Старт втроём?',
      body: 'Вы уверены, что хотите начать «$skillLabel» втроём?\n\n'
          'Для полной поддержки лучше команда из 4–6 человек: больше мотивации, '
          'отчётности и взаимной опоры. Но вы можете начать втроём уже сейчас — '
          'поиск остальных участников продолжится позже.',
      confirmLabel: 'Да, стартуем втроём',
      cancelLabel: 'Подождать команду',
      destructive: true,
    );
    if (agreed != true || !mounted) return;

    setState(() => _startingEarlyStart = true);
    try {
      final result = await context.read<ApiClient>().confirmEarlyStart(
            skillId: status.skillId,
          );
      if (!mounted) return;
      final matchedId = result['matched_group_id'] as String?;
      if (result['waiting_others_confirm'] == true ||
          result['waiting_partner_confirm'] == true) {
        showAppSnackBar(
          context,
          'Ждём подтверждения от других участников — нужно 3 подтверждения',
        );
      } else if (matchedId != null && matchedId.isNotEmpty) {
        showAppSnackBar(context, 'Команда из трёх человек собрана');
        _handledMatchedGroupId = matchedId;
      } else if (result['started'] == true) {
        showAppSnackBar(context, 'Команда из трёх человек собрана');
      }
      await context.read<WaitingRoomPoller>().refresh();
      if (mounted) {
        setState(() {
          _waitingRoom =
              context.read<WaitingRoomPoller>().status ?? _waitingRoom;
        });
      }
      await _load();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _startingEarlyStart = false);
    }
  }

  Future<void> _confirmStopSearch([WaitingRoomStatus? status]) async {
    final shouldStop = await showAppConfirmDialog(
      context: context,
      title: 'Остановить поиск?',
      body: 'Вы точно хотите остановить поиск?',
      cancelLabel: 'Продолжить поиск',
      confirmLabel: 'Остановить',
      destructive: true,
    );
    if (shouldStop != true || !mounted) return;
    await _stopSearch(status?.skillId);
  }

  Future<void> _stopSearch([String? skillId]) async {
    setState(() => _stopping = true);
    try {
      await context.read<ApiClient>().leaveWaitingRoom(
            skillId: skillId ?? _waitingRoom?.skillId,
          );
      if (!mounted) return;
      final poller = context.read<WaitingRoomPoller>();
      await poller.refresh();
      poller.stop();
      setState(() {
        _waitingRoom = poller.status;
        _waitingRoomStats = poller.stats;
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Поиск остановлен');
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  /// Expands the waiting room search to other regions for the SAME skill.
  ///
  /// Backend only supports widening the region for the currently queued
  /// skill (`POST /waiting-room/expand`) — there is no "search across all
  /// skills" endpoint. Do not add copy implying we search other habits;
  /// keep this explicitly about region so the UI stays honest about what
  /// actually happens server-side.
  Future<void> _expandSearch([WaitingRoomStatus? status]) async {
    final skillId = status?.skillId ?? _waitingRoom?.skillId;
    if (skillId == null || _expanding) return;
    final agreed = await showAppConfirmDialog(
      context: context,
      title: 'Искать по всей России?',
      body:
          'Сейчас мы ищем участников этой же привычки только в твоей области. '
          'Если согласишься, подключим поиск по всем областям России — привычка останется той же.',
      cancelLabel: 'Оставить область',
      confirmLabel: 'Да, искать везде',
    );
    if (agreed != true || !mounted) return;
    Analytics.instance.teamSearchConfigured(
      skillId: skillId,
      allowOtherRegions: true,
    );
    setState(() => _expanding = true);
    try {
      final result = await context.read<ApiClient>().expandWaitingRoom(skillId);
      if (mounted) {
        setState(() => _waitingRoom = WaitingRoomStatus.fromJson(result));
        await _load();
        if (!mounted) return;
        showAppSnackBar(context, 'Поиск расширен на другие области');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, FailureMapper.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  Future<void> _assembleTestTeam() async {
    final skillId = _waitingRoom?.skillId ?? widget.preselectedSkill?.id;
    if (skillId == null || skillId.isEmpty) {
      showAppSnackBar(context, 'Сначала выберите привычку');
      return;
    }
    setState(() => _assembling = true);
    try {
      final result = await context.read<ApiClient>().assembleTestTeam(skillId);
      final group = GroupModel.fromJson(result);
      if (!mounted) return;
      setState(() {
        _groups = [group, ..._groups.where((item) => item.id != group.id)];
        _waitingRoom = WaitingRoomStatus(
          inQueue: false,
          peopleWaiting: 0,
          needed: 6,
          matchedGroupId: group.id,
        );
        _handledMatchedGroupId = group.id;
      });
      Navigator.of(context).push(
        PrimeRoute.sharedAxis(
          builder: (_) => GroupDetailScreen(groupId: group.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _assembling = false);
    }
  }

  void _openMatchedGroup(String groupId) {
    _handledMatchedGroupId = groupId;
    unawaited(_openGroup(groupId));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppGroupSearchSkeleton();
    if (_error != null) {
      return AsyncErrorView(
        message: _error!,
        correlationId: _errorCorrelationId,
        onRetry: _load,
      );
    }

    final queueCards = _waitingRoom?.queues.isNotEmpty == true
        ? _waitingRoom!.queues
        : [
            if (_waitingRoom?.inQueue == true) _waitingRoom!,
          ];
    final inWaiting = queueCards.isNotEmpty;
    GroupModel? pendingConfirmationGroup;
    for (final g in _groups) {
      if (g.status == GroupStatus.introduction ||
          g.status == GroupStatus.rulesPending) {
        pendingConfirmationGroup = g;
        break;
      }
    }
    final matchedGroupId =
        _waitingRoom?.matchedGroupId ?? pendingConfirmationGroup?.id;
    GroupModel? matchedGroup = pendingConfirmationGroup;
    for (final g in _groups) {
      if (g.id == matchedGroupId) {
        matchedGroup = g;
        break;
      }
    }
    final userId = context.read<AuthProvider>().user?.id;
    final prep = matchedGroup != null
        ? GroupPrepStateResolver.resolve(
            group: matchedGroup,
            currentUserId: userId,
          )
        : null;
    final showPendingBanner = matchedGroup != null &&
        (matchedGroup.status == GroupStatus.introduction ||
            matchedGroup.status == GroupStatus.rulesPending);
    final currentUserId = context.watch<AuthProvider>().user?.id;
    MemberModel? myMember;
    if (currentUserId != null && matchedGroup != null) {
      for (final member in matchedGroup.members) {
        if (member.userId == currentUserId) {
          myMember = member;
          break;
        }
      }
    }
    final devMode = context.watch<AuthProvider>().developerMode;
    final activeGroups =
        _groups.where((g) => g.status == GroupStatus.active).toList();
    final otherGroups =
        _groups.where((g) => g.status != GroupStatus.active).toList();
    final hasCycleContent = _groups.isNotEmpty;
    final hasActiveModeContent = hasCycleContent || showPendingBanner;
    final hasSearchModeContent = inWaiting || widget.preselectedSkill != null;
    final showModeSwitch = hasActiveModeContent && hasSearchModeContent;
    final visibleMode = showModeSwitch
        ? _mode
        : hasActiveModeContent
            ? _GroupsMode.active
            : _GroupsMode.search;

    return AmbientCanvas(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: KitLayout.tabScrollPadding(
                context,
                left: AppSpacing.md,
                top: AppSpacing.md,
                right: AppSpacing.md,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PrimeTabContentFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Мои группы',
                          style: AppTypography.titleXL,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        const Text(
                          'Команда из шести — ритм, поддержка и общий прогресс',
                          style: AppTypography.bodySecondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (NativePushService.instance.degraded) ...[
                          const AppPushDegradedBanner(),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_membershipInconsistent) ...[
                          _MembershipAuditBanner(
                            onReconcile: _reconcileMembership,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (showModeSwitch) ...[
                          _GroupsModeSwitch(
                            value: visibleMode,
                            activeCount: _groups.length,
                            searchCount: queueCards.length,
                            onChanged: (value) => setState(() => _mode = value),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (visibleMode == _GroupsMode.active &&
                            showPendingBanner &&
                            prep != null) ...[
                          if (matchedGroup.status == GroupStatus.rulesPending)
                            GateGroupsRulesPendingCard.fromPresentation(
                              prep: prep,
                              onOpen: () => _openMatchedGroup(matchedGroup!.id),
                              skillName: _waitingRoom?.skillName ??
                                  matchedGroup.skillName,
                              userAccepted: myMember?.acceptedRules ?? false,
                            )
                          else
                            GateGroupsConfirmationCard.fromPresentation(
                              prep: prep,
                              onConfirm: () =>
                                  _openMatchedGroup(matchedGroup!.id),
                              skillName: _waitingRoom?.skillName ??
                                  matchedGroup.skillName,
                              userConfirmed:
                                  myMember?.confirmedParticipation ?? false,
                            ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (visibleMode == _GroupsMode.active &&
                            hasCycleContent) ...[
                          const _SectionHeader(
                            title: 'Мой темп',
                            subtitle: 'Активные команды и прогресс дня',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (activeGroups.isNotEmpty)
                            for (final group in activeGroups)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _ActiveGroupDayCard(
                                  group: group,
                                  onOpenGroup: _openGroup,
                                  onNudgeGroup: _nudgeGroups,
                                ),
                              ),
                          for (final group in otherGroups)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _GroupTile(
                                group: group,
                                onTap: () => _openGroup(group.id),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (visibleMode == _GroupsMode.search && inWaiting) ...[
                          if (queueCards.length > 1) ...[
                            const _SectionHeader(
                              title: 'Поиск',
                              subtitle: 'Собираем команду из 6 человек',
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Ищем команду по ${queueCards.length} привычкам — стартёт первая собранная',
                              style: AppTypography.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          _SearchQueuesPanel(
                            queues: queueCards,
                            stats: _waitingRoomStats,
                            stopping: _stopping,
                            expanding: _expanding,
                            startingEarlyStart: _startingEarlyStart,
                            onStop: _confirmStopSearch,
                            onExpand: _expandSearch,
                            onEarlyStart: _confirmEarlyStart,
                          ),
                          if (devMode) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _DevAssembleButton(
                              loading: _assembling,
                              onPressed: _assembleTestTeam,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ] else if (visibleMode == _GroupsMode.search &&
                            widget.preselectedSkill != null) ...[
                          const _SectionHeader(
                            title: 'Поиск',
                            subtitle: 'Собираем команду из 6 человек',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SkillStartCard(
                            skill: widget.preselectedSkill!,
                            joining: _joining,
                            onStart: _startSearch,
                          ),
                          if (devMode) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _DevAssembleButton(
                              loading: _assembling,
                              onPressed: _assembleTestTeam,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_groups.isEmpty && !inWaiting && !showPendingBanner)
                          const AppGroupEmptyState(),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reconcileMembership() async {
    try {
      await context.read<ApiClient>().reconcileMembership();
      if (!mounted) return;
      setState(() => _membershipInconsistent = false);
      await _load();
      if (!mounted) return;
      showAppSnackBar(context, 'Состояние команды восстановлено');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    }
  }

  Future<void> _openGroup(String groupId) async {
    await openGroupDetail(
      context,
      groupId: groupId,
      host: ({preferSearchTab = false, skillId}) {
          if (!mounted) return;
          if (preferSearchTab) {
            setState(() => _mode = _GroupsMode.search);
          }
        },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _nudgeGroups(List<GroupModel> groups) async {
    final targets =
        TeamDayPresentationResolver.groupsNeedingNudge(groups);
    if (targets.isEmpty) {
      if (!mounted) return;
      showAppSnackBar(context, 'День уже закрыт — все отчитались');
      return;
    }
    var sent = 0;
    var alreadyComplete = 0;
    for (final group in targets) {
      try {
        final result = await context.read<ApiClient>().nudgeGroup(group.id);
        if (!mounted) return;
        if (result['already_complete'] as bool? ?? false) {
          alreadyComplete++;
        } else {
          sent++;
        }
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, FailureMapper.from(e).message);
        return;
      }
    }
    final list = await context.read<ApiClient>().listGroups();
    if (!mounted) return;
    setState(() {
      _groups = list
          .map((j) => GroupModel.fromJson(j as Map<String, dynamic>))
          .toList();
    });
    if (!mounted) return;
    if (sent > 0) {
      showAppSnackBar(
        context,
        targets.length > 1
            ? 'Напоминания отправлены · $sent из ${targets.length}'
            : 'Напоминание отправлено команде',
      );
    } else if (alreadyComplete > 0) {
      showAppSnackBar(context, 'День уже закрыт — все отчитались');
    }
  }
}

enum _GroupsMode { active, search }

class _GroupsModeSwitch extends StatelessWidget {
  const _GroupsModeSwitch({
    required this.value,
    required this.activeCount,
    required this.searchCount,
    required this.onChanged,
  });

  final _GroupsMode value;
  final int activeCount;
  final int searchCount;
  final ValueChanged<_GroupsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GroupsModeButton(
              label: 'Активные',
              count: activeCount,
              selected: value == _GroupsMode.active,
              icon: Icons.bolt_rounded,
              onTap: () => onChanged(_GroupsMode.active),
            ),
          ),
          Expanded(
            child: _GroupsModeButton(
              label: 'Поиск',
              count: searchCount,
              selected: value == _GroupsMode.search,
              icon: Icons.group_add_outlined,
              onTap: () => onChanged(_GroupsMode.search),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsModeButton extends StatelessWidget {
  const _GroupsModeButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: selected
                ? Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.48),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    selected ? AppColors.primarySoft : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  '$label $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveGroupDayCard extends StatelessWidget {
  const _ActiveGroupDayCard({
    required this.group,
    required this.onOpenGroup,
    required this.onNudgeGroup,
  });

  final GroupModel group;
  final Future<void> Function(String groupId) onOpenGroup;
  final Future<void> Function(List<GroupModel> groups) onNudgeGroup;

  @override
  Widget build(BuildContext context) {
    return GateGroupsActiveHabitCard.fromGroup(
      group: group,
      onReport: () => onOpenGroup(group.id),
      onNudge: () => onNudgeGroup([group]),
      onOpen: () => onOpenGroup(group.id),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTypography.titleSerif,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTypography.bodySecondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Divider(color: AppColors.border.withValues(alpha: 0.6), height: 1),
      ],
    );
  }
}

class _SearchQueuesPanel extends StatefulWidget {
  const _SearchQueuesPanel({
    required this.queues,
    this.stats,
    required this.stopping,
    required this.expanding,
    required this.startingEarlyStart,
    required this.onStop,
    required this.onExpand,
    required this.onEarlyStart,
  });

  final List<WaitingRoomStatus> queues;
  final WaitingRoomStats? stats;
  final bool stopping;
  final bool expanding;
  final bool startingEarlyStart;
  final Future<void> Function([WaitingRoomStatus? status]) onStop;
  final Future<void> Function([WaitingRoomStatus? status]) onExpand;
  final Future<void> Function(WaitingRoomStatus status) onEarlyStart;

  @override
  State<_SearchQueuesPanel> createState() => _SearchQueuesPanelState();
}

class _SearchQueuesPanelState extends State<_SearchQueuesPanel> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _SearchQueuesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.queues.length) {
      _selectedIndex = 0;
    }
  }

  void _selectQueue(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queues.isEmpty) return const SizedBox.shrink();
    final selected = widget.queues[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.queues.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < widget.queues.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  AppSearchQueueChip(
                    label: widget.queues[i].skillName ??
                        widget.queues[i].skillId ??
                        'Привычка',
                    filled: widget.queues[i].peopleWaiting,
                    needed: widget.queues[i].needed > 0
                        ? widget.queues[i].needed
                        : 6,
                    selected: i == _selectedIndex,
                    expanded: widget.queues[i].allowOtherRegions,
                    onTap: () => _selectQueue(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _SearchCard(
          status: selected,
          stats: widget.stats,
          stopping: widget.stopping,
          expanding: widget.expanding,
          startingEarlyStart: widget.startingEarlyStart,
          onStop: () => widget.onStop(selected),
          onExpand: () => widget.onExpand(selected),
          onEarlyStart: () => widget.onEarlyStart(selected),
        ),
      ],
    );
  }
}

class _SkillStartCard extends StatelessWidget {
  final SkillModel skill;
  final bool joining;
  final VoidCallback onStart;

  const _SkillStartCard({
    required this.skill,
    required this.joining,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor('${skill.id} ${skill.name} ${skill.icon}');
    final promise = habitPromise(kind);
    return AppTeamFormationHero(
      title: skill.name,
      body: skill.description.isNotEmpty ? skill.description : promise,
      filled: 0,
      total: 6,
      actionLabel: joining ? AppCopy.searchingTeam : AppCopy.findTeam,
      onAction: joining ? null : onStart,
      loading: joining,
    );
  }
}

class _SearchCard extends StatefulWidget {
  final WaitingRoomStatus status;
  final WaitingRoomStats? stats;
  final bool stopping;
  final bool expanding;
  final bool startingEarlyStart;
  final VoidCallback onStop;
  final VoidCallback onExpand;
  final VoidCallback onEarlyStart;

  const _SearchCard({
    required this.status,
    this.stats,
    required this.stopping,
    required this.expanding,
    required this.startingEarlyStart,
    required this.onStop,
    required this.onExpand,
    required this.onEarlyStart,
  });

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  late bool _scopeRussia;
  Map<String, dynamic>? _preferences;
  String? _dismissedEarlyStartRequestId;

  @override
  void initState() {
    super.initState();
    _scopeRussia = widget.status.allowOtherRegions;
    unawaited(_loadPreferences());
  }

  @override
  void didUpdateWidget(covariant _SearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.allowOtherRegions) {
      _scopeRussia = true;
    }
  }

  void _onScopeCity() {
    if (widget.status.allowOtherRegions) {
      setState(() => _scopeRussia = false);
    }
  }

  void _onScopeRussia() {
    if (widget.status.allowOtherRegions) {
      setState(() => _scopeRussia = true);
      return;
    }
    if (widget.status.canExpandSearch && !widget.expanding) {
      widget.onExpand();
    }
  }

  Future<void> _openInviteFriends() async {
    final skillId = widget.status.skillId;
    if (skillId == null || skillId.isEmpty) return;
    final skillName =
        widget.status.skillName ?? widget.status.skillId ?? 'привычка';
    await showInviteFriendsSheet(
      context,
      skillId: skillId,
      skillName: skillName,
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await context.read<ApiClient>().getPreferences();
      if (mounted) setState(() => _preferences = prefs);
    } catch (_) {}
  }

  Future<void> _openAboutSheet() async {
    await showAboutBeforeTeamSheet(
      context,
      reason: AboutBeforeTeamReason.search,
    );
  }

  Future<void> _openRhythmSupport() async {
    final saved = await showRhythmSupportSheet(context);
    if (saved == true && mounted) {
      await _loadPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final needed = status.needed > 0 ? status.needed : 6;
    final waiting = status.peopleWaiting;
    final skillName =
        status.skillName ?? status.skillId ?? 'выбранная привычка';
    final regionLabel = status.regionName == null
        ? 'вашем регионе'
        : status.allowOtherRegions
            ? '${status.regionName} + другие области'
            : status.regionName!;
    final regionSearching = status.regionSearching > 0
        ? status.regionSearching
        : (widget.stats?.regionSearching ?? waiting);
    final skillSearching = status.skillSearching > 0
        ? status.skillSearching
        : (widget.stats?.skillSearching ?? waiting);
    final onlineInPool = status.onlineInPool > 0
        ? status.onlineInPool
        : (widget.stats?.onlineInPool ?? 0);
    final about = context.watch<AuthProvider>().user?.about.trim() ?? '';
    final aboutReady =
        about.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 3;
    final hasEarlyStartProposal =
        status.earlyStartPending || status.earlyStartWaitingOthers;
    final showEarlyStartBanner = hasEarlyStartProposal &&
        status.earlyStartRequestId != _dismissedEarlyStartRequestId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showEarlyStartBanner) ...[
          AppEarlyStartBanner(
            status: status,
            loading: widget.startingEarlyStart,
            onConfirm: widget.onEarlyStart,
            onKeepWaiting: () => setState(
              () => _dismissedEarlyStartRequestId =
                  status.earlyStartRequestId ?? 'legacy',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        GateGroupsPresentation(
          habitName: skillName,
          found: waiting,
          total: needed,
          scopeLabel: status.allowOtherRegions ? 'По всей России' : regionLabel,
          regionSearching: regionSearching,
          skillSearching: skillSearching,
          onlineInPool: onlineInPool,
          scopeIsRussia: _scopeRussia,
          canExpandSearch: status.canExpandSearch,
          expansionAvailableAt: status.expansionAvailableAt,
          expanding: widget.expanding,
          status: status,
          showEarlyStartPanel: !hasEarlyStartProposal,
          checklist: gateReadinessFromProfile(
            aboutReady: aboutReady,
            preferences: _preferences,
          ),
          onExpandSearch: status.canExpandSearch && !widget.expanding
              ? widget.onExpand
              : null,
          onStopSearch: widget.stopping ? null : widget.onStop,
          onScopeCity: _onScopeCity,
          onScopeRussia: _onScopeRussia,
          onEarlyStart: status.canStartEarly && !status.earlyStartWaitingOthers
              ? widget.onEarlyStart
              : null,
          startingEarlyStart: widget.startingEarlyStart,
          onChecklistTap: (item) {
            switch (item.title) {
              case 'О себе':
                unawaited(_openAboutSheet());
              case 'Ритм и поддержка':
                unawaited(_openRhythmSupport());
              case 'Пригласить друга':
                unawaited(_openInviteFriends());
            }
          },
          showPageHeader: false,
        ),
        if (status.events.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppWaitingRoomEventTicker(events: status.events),
        ],
      ],
    );
  }
}

class _PreSearchBullet extends StatelessWidget {
  const _PreSearchBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: AppTypography.bodySecondary),
          ),
        ],
      ),
    );
  }
}

class _MembershipAuditBanner extends StatelessWidget {
  const _MembershipAuditBanner({required this.onReconcile});

  final Future<void> Function() onReconcile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_problem_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Данные команды рассинхронизированы. Можно восстановить '
                  'состояние без перезапуска приложения.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => unawaited(onReconcile()),
                  child: const Text('Восстановить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DevAssembleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _DevAssembleButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppSecondaryButton(
      label: loading
          ? 'Собираем тестовую команду...'
          : 'Собрать команду из тестеров',
      icon: Icons.construction,
      loading: loading,
      onPressed: loading ? null : onPressed,
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;
  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GateGroupsListTile(
      title: group.skillName ?? group.name,
      statusLabel: gateGroupStatusLabel(group.status),
      membersCount: group.membersCount,
      maxMembers: group.maxMembers,
      skillId: group.skillId,
      active: group.status == GroupStatus.active,
      onTap: onTap,
    );
  }
}
