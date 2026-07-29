import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics.dart';
import '../core/errors/failure_mapper.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/routes.dart';
import '../design/glass.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/copy.dart';
import '../models/group.dart';
import '../models/skill.dart';
import '../providers/auth_provider.dart';
import '../screens/group_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/habit_art.dart';
import '../ui/components/app_destructive_button.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_primary_button.dart';
import '../ui/components/app_secondary_button.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/app_skeleton.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/editorial/app_team_formation.dart';
import '../ui/components/groups/invite_friends_sheet.dart';
import '../widgets/async_error_view.dart';

class GroupsScreen extends StatefulWidget {
  final SkillModel? preselectedSkill;
  final int refreshToken;

  const GroupsScreen({
    super.key,
    this.preselectedSkill,
    this.refreshToken = 0,
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
  String? _error;
  String? _errorCorrelationId;
  String? _handledMatchedGroupId;
  WaitingRoomPoller? _poller;

  @override
  void initState() {
    super.initState();
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
      final list = await api.listGroups();
      _groups = list
          .map((j) => GroupModel.fromJson(j as Map<String, dynamic>))
          .toList();
      await poller.refresh();
      _waitingRoom = poller.status ??
          WaitingRoomStatus.fromJson(await api.waitingRoomStatus(
            skillId: widget.preselectedSkill?.id,
          ));
      _waitingRoomStats = poller.stats;
      if (_waitingRoom?.inQueue == true ||
          (_waitingRoom?.queues.isNotEmpty ?? false)) {
        poller.start();
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
      });
      context.read<WaitingRoomPoller>().start();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _joining = false);
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
      await _load();
      if (!mounted) return;
      showAppSnackBar(context, 'Поиск остановлен');
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
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupDetailScreen(groupId: groupId),
      ),
    );
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
    final matchedGroupId = _waitingRoom?.matchedGroupId;
    final showMatchCta = matchedGroupId != null && matchedGroupId.isNotEmpty;
    final devMode = context.watch<AuthProvider>().developerMode;
    final activeGroups =
        _groups.where((g) => g.status == GroupStatus.active).toList();
    final otherGroups =
        _groups.where((g) => g.status != GroupStatus.active).toList();
    final hasCycleContent = _groups.isNotEmpty;

    return AmbientCanvas(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.bottomNavClearance,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Мои группы',
                    style: AppTypography.display,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  const Text(
                    'Команда из шести — ритм, поддержка и общий прогресс',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (showMatchCta) ...[
                    AppGroupMatchedBanner(
                      onOpen: () => _openMatchedGroup(matchedGroupId),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (hasCycleContent) ...[
                    _SectionHeader(title: 'Мой цикл'),
                    const SizedBox(height: AppSpacing.sm),
                    if (activeGroups.isNotEmpty) ...[
                      for (final group in activeGroups) ...[
                        _TeamDayCard(
                          group: group,
                          onOpenGroup: () => _openGroup(group.id),
                          onNudge: () => _nudgeGroup(group),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (activeGroups.length == 1) ...[
                        AppGroupActiveCycleHero(
                          group: activeGroups.first,
                          onTap: () => _openGroup(activeGroups.first.id),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ] else
                        for (final group in activeGroups)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _GroupTile(
                              group: group,
                              onTap: () => _openGroup(group.id),
                            ),
                          ),
                    ],
                    for (final group in otherGroups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _GroupTile(
                          group: group,
                          onTap: () => _openGroup(group.id),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (inWaiting) ...[
                    _SectionHeader(title: 'Поиск'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      queueCards.length == 1
                          ? 'Ищем команду по привычке — поиск идёт в фоне'
                          : 'Ищем команду по ${queueCards.length} привычкам — стартёт первая собранная',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SearchQueuesPanel(
                      queues: queueCards,
                      stats: _waitingRoomStats,
                      stopping: _stopping,
                      expanding: _expanding,
                      onStop: _confirmStopSearch,
                      onExpand: _expandSearch,
                    ),
                    if (devMode) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _DevAssembleButton(
                        loading: _assembling,
                        onPressed: _assembleTestTeam,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ] else if (widget.preselectedSkill != null) ...[
                    _SectionHeader(title: 'Поиск'),
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
                  if (_groups.isEmpty && !inWaiting && !showMatchCta)
                    const AppGroupEmptyState(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroup(String groupId) {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupDetailScreen(groupId: groupId),
      ),
    );
  }

  Future<void> _nudgeGroup(GroupModel group) async {
    try {
      final result = await context.read<ApiClient>().nudgeGroup(group.id);
      if (!mounted) return;
      final alreadyComplete = result['already_complete'] as bool? ?? false;
      showAppSnackBar(
        context,
        alreadyComplete
            ? 'День уже закрыт — все отчитались'
            : 'Напоминание отправлено команде',
      );
      final list = await context.read<ApiClient>().listGroups();
      if (!mounted) return;
      setState(() {
        _groups = list
            .map((j) => GroupModel.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    }
  }
}

class _TeamDayCard extends StatelessWidget {
  const _TeamDayCard({
    required this.group,
    required this.onOpenGroup,
    required this.onNudge,
  });

  final GroupModel group;
  final VoidCallback onOpenGroup;
  final VoidCallback onNudge;

  @override
  Widget build(BuildContext context) {
    final teamDay = group.teamDay;
    final pulse = group.teamPulse;
    final ready = teamDay?.readyCount ?? pulse?.completedToday ?? 0;
    final total = teamDay?.memberCount ??
        pulse?.totalActive ??
        group.membersCount.clamp(1, group.maxMembers);
    final waiting = teamDay?.waitingFor.isNotEmpty == true
        ? teamDay!.waitingFor
        : (pulse?.waitingFor ?? const <TeamWaitingMember>[]);
    final remaining = teamDay?.remaining ??
        (total - ready).clamp(0, total);
    final complete = teamDay?.isComplete == true ||
        pulse?.isTeamDayComplete == true;
    final progress = total > 0 ? (ready / total).clamp(0.0, 1.0) : 0.0;
    final waitingNames = waiting
        .map((m) => m.displayName)
        .where((name) => name.isNotEmpty)
        .take(4)
        .join(', ');

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      fillOpacity: 0.04,
      glow: AppGlow.violet(
        opacity: complete ? 0.08 : 0.14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppProgressRing(
                progress: progress,
                label: '$ready',
                subtitle: 'из $total',
                size: 72,
                stroke: 5,
                color: complete ? AppColors.success : AppColors.habitSocial,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.dayClosesTogether,
                      style: AppTypography.title2,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      complete
                          ? 'Командный день закрыт'
                          : AppCopy.waitingReports(remaining),
                      style: AppTypography.caption.copyWith(
                        color: complete
                            ? AppColors.success
                            : AppColors.primarySoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      complete
                          ? AppCopy.primesForTeamDay
                          : waitingNames.isNotEmpty
                              ? 'Ждём: $waitingNames'
                              : AppCopy.howDayCounts,
                      style: AppTypography.bodySecondary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Отправить отчёт',
            icon: Icons.edit_note_outlined,
            onPressed: onOpenGroup,
          ),
          if (!complete) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: AppCopy.nudgeTeam,
              icon: Icons.notifications_active_outlined,
              onPressed: onNudge,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.titleSerif);
  }
}

class _SearchQueuesPanel extends StatefulWidget {
  const _SearchQueuesPanel({
    required this.queues,
    this.stats,
    required this.stopping,
    required this.expanding,
    required this.onStop,
    required this.onExpand,
  });

  final List<WaitingRoomStatus> queues;
  final WaitingRoomStats? stats;
  final bool stopping;
  final bool expanding;
  final Future<void> Function([WaitingRoomStatus? status]) onStop;
  final Future<void> Function([WaitingRoomStatus? status]) onExpand;

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
          onStop: () => widget.onStop(selected),
          onExpand: () => widget.onExpand(selected),
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
  final VoidCallback onStop;
  final VoidCallback onExpand;

  const _SearchCard({
    required this.status,
    this.stats,
    required this.stopping,
    required this.expanding,
    required this.onStop,
    required this.onExpand,
  });

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  void _openProfile() {
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => const ProfileScreen()),
    );
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

  String? _medianLine(WaitingRoomStatus status) {
    final hours = status.medianMatchHours ?? widget.stats?.medianMatchHours;
    if (hours == null) return null;
    final rounded = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1);
    return 'Обычно собирается за ~$rounded ч';
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
    final liveRegionLine =
        'В $regionLabel сейчас ищут $regionSearching, из них $skillSearching — вашу привычку · онлайн $onlineInPool';
    final about = context.watch<AuthProvider>().user?.about.trim() ?? '';
    final aboutReady = about.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTeamFormationHero(
          title: skillName,
          body: status.allowOtherRegions
              ? 'Ищем по всей России — подключаем участников из других областей'
              : 'Сначала ищем рядом: $regionLabel. Если не соберёмся — можно расширить.',
          filled: waiting,
          total: needed,
          statusLine: waiting >= needed
              ? 'почти готово · $waiting из $needed'
              : 'в поиске · собрано $waiting из $needed',
          regionLine: liveRegionLine,
          medianLine: _medianLine(status),
          anonymousSlots: status.slots,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SearchPrepChecklist(
          aboutReady: aboutReady,
          onAbout: _openProfile,
          onTimeOfDay: () => showAppSnackBar(
            context,
            'Выбор времени дня скоро появится в профиле',
          ),
          onInviteFriend: _openInviteFriends,
        ),
        if (status.events.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppWaitingRoomEventTicker(events: status.events),
        ],
        const SizedBox(height: AppSpacing.sm),
        GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          fillOpacity: 0.04,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSearchTimeline(status: status),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppCopy.waitPrepTip,
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Поиск продолжается в фоне. Можно перейти на другие экраны и вернуться позже.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              // Region-only expansion — see _expandSearch doc comment above.
              // Never label this as "search all habits/skills": the backend
              // has no cross-skill matching, only cross-region for the same skill.
              if (status.canExpandSearch) ...[
                AppPrimaryButton(
                  label: 'Искать по всей России',
                  icon: Icons.public,
                  loading: widget.expanding,
                  onPressed: widget.expanding ? null : widget.onExpand,
                ),
                const SizedBox(height: AppSpacing.sm),
              ] else if (status.allowOtherRegions) ...[
                Text(
                  'Ищем участников по всей России',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primarySoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppDestructiveButton(
                label: AppCopy.stopSearch,
                loading: widget.stopping,
                onPressed: widget.stopping ? null : widget.onStop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchPrepChecklist extends StatelessWidget {
  const _SearchPrepChecklist({
    required this.aboutReady,
    required this.onAbout,
    required this.onTimeOfDay,
    required this.onInviteFriend,
  });

  final bool aboutReady;
  final VoidCallback onAbout;
  final VoidCallback onTimeOfDay;
  final VoidCallback onInviteFriend;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      fillOpacity: 0.04,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Пока ждёте — чеклист',
            style: AppTypography.caption.copyWith(
              color: AppColors.primarySoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistRow(
            done: aboutReady,
            label: 'О себе',
            statusLabel: aboutReady ? 'заполнено' : 'дополнить',
            onTap: onAbout,
          ),
          _ChecklistRow(
            done: false,
            label: 'Время дня',
            statusLabel: 'скоро',
            onTap: onTimeOfDay,
          ),
          _ChecklistRow(
            done: false,
            label: AppCopy.inviteFriend,
            statusLabel: 'в пару',
            onTap: onInviteFriend,
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.label,
    required this.statusLabel,
    required this.onTap,
  });

  final bool done;
  final String label;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: AppTypography.body),
            ),
            Text(
              statusLabel,
              style: AppTypography.caption.copyWith(
                color: done ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
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
    const statusLabels = {
      GroupStatus.forming: 'набор',
      GroupStatus.introduction: 'знакомство',
      GroupStatus.rulesPending: 'принятие правил',
      GroupStatus.active: 'активна',
      GroupStatus.rotating: 'добор',
      GroupStatus.voting: 'голосование',
      GroupStatus.completed: 'завершена',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGroupListRow(
        title: group.skillName ?? group.name,
        statusLabel: statusLabels[group.status] ?? '—',
        membersCount: group.membersCount,
        maxMembers: group.maxMembers,
        active: group.status == GroupStatus.active,
        onTap: onTap,
      ),
    );
  }
}
