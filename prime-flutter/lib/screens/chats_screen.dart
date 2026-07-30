import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/failure_mapper.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../ui/kit/presentation/gate_chats_presentation.dart';
import '../ui/kit/presentation/profile_surfaces.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../l10n/copy.dart';
import '../models/direct_chat.dart';
import '../providers/chats_inbox_provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/editorial/app_friend_search.dart';
import '../ui/components/social/users_discover_panel.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/groups/invite_friends_sheet.dart';
import '../ui/components/profile/app_avatar.dart';
import '../ui/kit/components/prime_empty_state.dart';
import '../ui/kit/components/prime_list_row.dart';
import '../ui/kit/tokens/kit_layout.dart';
import '../ui/kit/tokens/kit_typography.dart';
import '../ui/states/app_empty_state.dart';
import '../widgets/async_error_view.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';

enum _ChatsSegment { team, personal, people }

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.onFindFriend,
    this.openFriendSearch = false,
    this.onFriendSearchOpened,
    this.onOpenGroups,
  });

  final VoidCallback? onFindFriend;
  final bool openFriendSearch;
  final VoidCallback? onFriendSearchOpened;
  final VoidCallback? onOpenGroups;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<GroupModel> _teamGroups = [];
  List<UserPublic> _friends = [];
  UserPublic? _selectedFriend;
  String? _error;
  String? _errorCorrelationId;
  _ChatsSegment _segment = _ChatsSegment.team;

  @override
  void initState() {
    super.initState();
    if (widget.openFriendSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFriendSearchSheet();
      });
    }
    _load();
  }

  int _segmentIndex(_ChatsSegment segment) {
    switch (segment) {
      case _ChatsSegment.team:
        return 0;
      case _ChatsSegment.personal:
        return 1;
      case _ChatsSegment.people:
        return 2;
    }
  }

  _ChatsSegment _segmentFromIndex(int index) {
    switch (index) {
      case 0:
        return _ChatsSegment.team;
      case 2:
        return _ChatsSegment.people;
      default:
        return _ChatsSegment.personal;
    }
  }

  Future<void> _openFriendSearchSheet() async {
    widget.onFriendSearchOpened?.call();
    await showFriendSearchSheet(context, onChanged: _refreshAfterFriendAction);
  }

  Future<void> _refreshAfterFriendAction() async {
    if (!mounted) return;
    final api = context.read<ApiClient>();
    final inbox = context.read<ChatsInboxProvider>();
    inbox.invalidate();
    try {
      final results = await Future.wait<dynamic>([
        api.listFriends(forceRefresh: true),
        inbox.ensureLoaded(force: true),
      ]);
      final friendRows = results[0] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _friends = friendRows
            .whereType<Map>()
            .map((row) => UserPublic.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        _segment = _ChatsSegment.personal;
      });
    } catch (_) {
      // Keep current lists if refresh fails.
    }
  }

  @override
  void didUpdateWidget(covariant ChatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openFriendSearch && !oldWidget.openFriendSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFriendSearchSheet();
      });
    }
  }

  Future<void> _load({bool force = false}) async {
    final inbox = context.read<ChatsInboxProvider>();
    unawaited(inbox.ensureLoaded(force: force));

    try {
      final api = context.read<ApiClient>();
      final results = await Future.wait<Object>([
        api.listGroups(),
        api.listFriends().catchError((_) => <dynamic>[]),
      ]);
      final groupRows = results[0] as List<dynamic>;
      final friendRows = results[1] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _friends = friendRows
            .whereType<Map>()
            .map((row) => UserPublic.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        _teamGroups = groupRows
            .map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
            .where(
              (g) =>
                  g.status == GroupStatus.active &&
                  g.matrixRoomId != null &&
                  g.matrixRoomId!.isNotEmpty,
            )
            .toList();
        final chats = inbox.chats;
        if (_selectedFriend != null &&
            !chats.any((c) => c.friend.id == _selectedFriend!.id)) {
          _selectedFriend = chats.isEmpty ? null : chats.first.friend;
        }
        _error = null;
        _errorCorrelationId = null;
      });
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        setState(() {
          _error = failure.message;
          _errorCorrelationId = failure.correlationId;
        });
      }
    }
  }

  String _teamDaySubtitle(GroupModel group) {
    final teamDay = group.teamDay;
    final pulse = group.teamPulse;
    final ready = teamDay?.readyCount ?? pulse?.completedToday ?? 0;
    final total = teamDay?.memberCount ??
        pulse?.totalActive ??
        group.membersCount.clamp(1, group.maxMembers);
    final complete = teamDay?.isComplete == true ||
        pulse?.isTeamDayComplete == true;
    if (complete) return 'день закрыт $ready/$total';
    final remaining = (total - ready).clamp(0, total);
    return AppCopy.waitingReports(remaining);
  }

  List<UserPublic> _friendsWithoutChat(List<DirectChatSummary> chats) {
    final chatIds = chats.map((c) => c.friend.id).toSet();
    return _friends.where((f) => !chatIds.contains(f.id)).toList();
  }

  Future<void> _inviteFriendToTeam() async {
    final waiting = context.read<WaitingRoomPoller>();
    final queueSkillId = waiting.status?.skillId ??
        (waiting.status?.queues.isNotEmpty == true
            ? waiting.status!.queues.first.skillId
            : null);
    final activeSkillId =
        _teamGroups.isNotEmpty ? _teamGroups.first.skillId : null;
    final skillId = (queueSkillId != null && queueSkillId.isNotEmpty)
        ? queueSkillId
        : activeSkillId;
    if (skillId == null || skillId.isEmpty) {
      showAppSnackBar(context, 'Сначала выберите привычку');
      return;
    }
    final skillName = waiting.status?.skillName ??
        (_teamGroups.isNotEmpty
            ? (_teamGroups.first.skillName ?? _teamGroups.first.name)
            : 'привычка');
    await showInviteFriendsSheet(
      context,
      skillId: skillId,
      skillName: skillName,
    );
  }

  String? _formatChatTime(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (diff == 0) return '$hh:$mm';
    if (diff == 1) return 'Вчера';
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd.$mo';
  }

  Future<void> _openChat(UserPublic friend, {required bool split}) async {
    unawaited(context.read<ApiClient>().warmDirectMessagesCache(friend.id));
    if (split) {
      setState(() => _selectedFriend = friend);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatsInboxProvider>().patchUnread(friend.id, unread: 0);
      });
      return;
    }
    await Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => DirectChatScreen(friend: friend),
      ),
    );
    if (mounted) {
      context.read<ChatsInboxProvider>().patchUnread(friend.id, unread: 0);
      unawaited(context.read<ChatsInboxProvider>().ensureLoaded(force: true));
    }
  }

  Future<void> _openGroupChat(GroupModel group) async {
    await Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => GroupChatScreen(
          groupId: group.id,
          groupName: group.skillName ?? group.name,
        ),
      ),
    );
  }

  Widget _teamSegment({required bool split}) {
    if (_teamGroups.isEmpty) {
      return PrimeEmptyState(
        title: 'Команда ещё не собрана',
        body:
            'Сначала выберите привычку и соберите команду из 6 — '
            'тогда здесь появится командный чат.',
        illustrationAsset: 'assets/illustrations/team_gathering.svg',
        actionLabel: widget.onOpenGroups != null ? 'К привычкам / командам' : null,
        onAction: widget.onOpenGroups,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Команда',
            style: KitTypography.sectionTitle.copyWith(color: AppColors.textPrimary),
          ),
        ),
        for (final group in _teamGroups)
          _chatListRow(
            title: group.skillName ?? group.name,
            subtitle: _teamDaySubtitle(group),
            initial: (group.skillName ?? group.name).isNotEmpty
                ? (group.skillName ?? group.name)[0].toUpperCase()
                : '?',
            time: group.cycleStartAt != null
                ? 'День ${AppGroupActiveCycleHero.cycleDayFromStart(group.cycleStartAt)}'
                : null,
            onTap: () => _openGroupChat(group),
          ),
      ],
    );
  }

  Widget _chatListRow({
    required String title,
    required String subtitle,
    required String initial,
    String? avatarUrl,
    String? time,
    int unread = 0,
    VoidCallback? onTap,
  }) {
    return PrimeListRow(
      leading: AppAvatar(photoUrl: avatarUrl, radius: 24, name: title),
      title: title,
      subtitle: subtitle,
      trailing: time != null
          ? Text(time, style: KitTypography.caption.copyWith(color: AppColors.textMuted))
          : null,
      badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
      onTap: onTap,
    );
  }

  Widget _inboxList({
    required List<DirectChatSummary> chats,
    required bool split,
    required int unreadCount,
    EdgeInsets? padding,
  }) {
    final bottomPad = split ? AppSpacing.md : KitLayout.scrollBottomFor(context);
    final isPeople = _segment == _ChatsSegment.people;

    final gate = GateChatsPresentation(
      chats: chats,
      segmentIndex: _segmentIndex(_segment),
      unreadCount: unreadCount,
      showPageHeader: !split,
      includePeopleBody: !isPeople,
      onSegmentChanged: (index) =>
          setState(() => _segment = _segmentFromIndex(index)),
      onFindFriend: _openFriendSearchSheet,
      onOpenPeople: () => setState(() => _segment = _ChatsSegment.people),
      onInviteLink: _inviteFriendToTeam,
      onChatTap: (friend) => _openChat(friend, split: split),
      onOpenGroups: widget.onOpenGroups,
      teamBody: _teamSegment(split: split),
      friendsWithoutChat: _friendsWithoutChat(chats),
      timeLabelFor: _formatChatTime,
    );

    if (isPeople) {
      final edgePadding = padding ??
          EdgeInsets.fromLTRB(
            split ? AppSpacing.md : 0,
            split ? AppSpacing.sm : 0,
            split ? AppSpacing.md : 0,
            0,
          );
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: edgePadding,
            sliver: SliverMainAxisGroup(
              slivers: [
                if (split)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        'Сообщения',
                        style: KitTypography.pageTitle.copyWith(fontSize: 28),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: gate),
                UsersDiscoverPanel(
                  asSliverHost: true,
                  onChanged: _refreshAfterFriendAction,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
        ],
      );
    }

    return ListView(
      padding: padding ??
          EdgeInsets.fromLTRB(
            split ? AppSpacing.md : 0,
            split ? AppSpacing.sm : 0,
            split ? AppSpacing.md : 0,
            bottomPad,
          ),
      children: [
        if (split)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Сообщения',
              style: KitTypography.pageTitle.copyWith(fontSize: 28),
            ),
          ),
        gate,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<ChatsInboxProvider>();
    final chats = inbox.chats;

    if (_error != null && chats.isEmpty && _friends.isEmpty) {
      return Scaffold(
        backgroundColor: ProfileSurfaces.canvas,
        body: ColoredBox(
          color: ProfileSurfaces.canvas,
          child: AmbientCanvas(
            intensity: 0.55,
            child: AsyncErrorView(
              message: _error!,
              correlationId: _errorCorrelationId,
              onRetry: () => _load(force: true),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= AppBreakpoints.tablet;

        if (split) {
          final friend = _selectedFriend ??
              (chats.isNotEmpty ? chats.first.friend : null);
          return Scaffold(
            backgroundColor: ProfileSurfaces.canvas,
            body: ColoredBox(
              color: ProfileSurfaces.canvas,
              child: AmbientCanvas(
                intensity: 0.55,
                child: Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: RefreshIndicator(
                        onRefresh: () => _load(force: true),
                        child: _inboxList(
                          chats: chats,
                          split: true,
                          unreadCount: inbox.unreadCount,
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppColors.border),
                    Expanded(
                      child: friend == null
                          ? const Center(
                              child: AppEmptyState(
                                title: 'Выберите чат',
                                subtitle:
                                    'Список слева — переписка откроется здесь.',
                                icon: Icons.chat_outlined,
                              ),
                            )
                          : DirectChatScreen(
                              key: ValueKey(friend.id),
                              friend: friend,
                              embedded: true,
                              onMessageSent: () {
                                _load();
                                unawaited(
                                  context
                                      .read<ChatsInboxProvider>()
                                      .ensureLoaded(force: true),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ProfileSurfaces.canvas,
          body: ColoredBox(
            color: ProfileSurfaces.canvas,
            child: AmbientCanvas(
              intensity: 0.55,
              child: RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: _inboxList(
                  chats: chats,
                  split: false,
                  unreadCount: inbox.unreadCount,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
