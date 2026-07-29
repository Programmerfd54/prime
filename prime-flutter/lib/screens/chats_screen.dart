import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../core/errors/failure_mapper.dart';
import '../core/sync/waiting_room_poller.dart';
import '../data/api_client.dart';
import '../design/glass.dart';
import '../design/routes.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../l10n/copy.dart';
import '../models/direct_chat.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../ui/components/app_dialog.dart';
import '../ui/components/app_skeleton.dart';
import '../ui/components/editorial/app_friend_search.dart';
import '../ui/components/editorial/app_group_editorial.dart';
import '../ui/components/app_snackbar.dart';
import '../ui/components/editorial/app_social_inbox.dart';
import '../ui/components/groups/invite_friends_sheet.dart';
import '../ui/components/profile/app_avatar.dart';
import '../ui/kit/components/prime_empty_state.dart';
import '../ui/kit/components/prime_list_row.dart';
import '../ui/kit/tokens/kit_layout.dart';
import '../ui/kit/tokens/kit_typography.dart';
import '../ui/states/app_empty_state.dart';
import '../widgets/async_error_view.dart';
import '../widgets/notification_bell_button.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';

enum _ChatsSegment { team, personal }

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.onFindFriend,
    this.refreshToken = 0,
    this.openFriendSearch = false,
    this.onFriendSearchOpened,
    this.onUnreadChanged,
    this.onOpenGroups,
  });

  final VoidCallback? onFindFriend;
  final int refreshToken;
  final bool openFriendSearch;
  final VoidCallback? onFriendSearchOpened;
  final VoidCallback? onUnreadChanged;
  final VoidCallback? onOpenGroups;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<DirectChatSummary> _chats = [];
  List<GroupModel> _teamGroups = [];
  List<UserPublic> _friends = [];
  UserPublic? _selectedFriend;
  bool _loading = true;
  String? _error;
  String? _errorCorrelationId;
  _ChatsSegment _segment = _ChatsSegment.team;
  final _friendSearchCtrl = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _friendSearching = false;
  bool _friendRequestSending = false;
  bool _friendNotFound = false;
  String? _friendSearchError;

  @override
  void dispose() {
    _friendSearchCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _searchFriend() async {
    final nickname = _friendSearchCtrl.text.trim();
    if (nickname.isEmpty) return;
    setState(() {
      _friendSearching = true;
      _friendNotFound = false;
      _friendSearchError = null;
      _foundUser = null;
    });
    try {
      final result =
          await context.read<ApiClient>().findUserByNickname(nickname);
      if (!mounted) return;
      setState(() {
        _foundUser = result;
        _friendNotFound = result['user'] == null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _friendSearchError = ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _friendSearching = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final nickname = _friendSearchCtrl.text.trim();
    if (nickname.isEmpty || _friendRequestSending) return;
    setState(() => _friendRequestSending = true);
    try {
      await context.read<ApiClient>().sendFriendRequestByNickname(nickname);
      if (!mounted) return;
      showAppSnackBar(context, 'Заявка отправлена');
      await _searchFriend();
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _friendRequestSending = false);
    }
  }

  Future<void> _cancelFriendRequest() async {
    final requestId = _foundUser?['pending_request_id'] as String?;
    if (requestId == null || requestId.isEmpty) return;
    try {
      await context.read<ApiClient>().cancelFriendRequest(requestId);
      await _searchFriend();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    }
  }

  void _writeToFoundFriend() {
    final user = _foundUser?['user'] as Map<String, dynamic>?;
    if (user == null) return;
    final friend = UserPublic.fromJson(user);
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => DirectChatScreen(friend: friend)),
    );
  }

  Future<void> _openFriendSearchSheet() async {
    widget.onFriendSearchOpened?.call();
    await showAppBottomSheet<void>(
      context: context,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppFriendSearchPanel(
            controller: _friendSearchCtrl,
            foundUser: _foundUser,
            searching: _friendSearching,
            sendingRequest: _friendRequestSending,
            notFound: _friendNotFound,
            error: _friendSearchError,
            avatarUrl: _avatarUrl(
              (_foundUser?['user'] as Map<String, dynamic>?)?['photo_url']
                  as String?,
            ),
            onSearch: _searchFriend,
            onAddFriend: _sendFriendRequest,
            onCancelRequest: _cancelFriendRequest,
            onWrite: _writeToFoundFriend,
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ChatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
    if (widget.openFriendSearch && !oldWidget.openFriendSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFriendSearchSheet();
      });
    }
  }

  Future<void> _load() async {
    if (mounted && _chats.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
        _errorCorrelationId = null;
      });
    }
    try {
      final api = context.read<ApiClient>();
      final results = await Future.wait<Object>([
        api.listDirectChats(),
        api.listGroups(),
        api.listFriends().catchError((_) => <dynamic>[]),
      ]);
      final rows = results[0] as List<dynamic>;
      final groupRows = results[1] as List<dynamic>;
      final friendRows = results[2] as List<dynamic>;
      final friends = friendRows
          .whereType<Map>()
          .map((row) => UserPublic.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final chats = rows
          .map((item) => DirectChatSummary.fromJson(item as Map<String, dynamic>))
          .toList();
      final teamGroups = groupRows
          .map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
          .where(
            (g) =>
                g.status == GroupStatus.active &&
                g.matrixRoomId != null &&
                g.matrixRoomId!.isNotEmpty,
          )
          .toList();
      if (mounted) {
        setState(() {
          _chats = chats;
          _teamGroups = teamGroups;
          _friends = friends;
          if (_selectedFriend != null &&
              !chats.any((c) => c.friend.id == _selectedFriend!.id)) {
            _selectedFriend = chats.isEmpty ? null : chats.first.friend;
          } else if (_selectedFriend == null && chats.isNotEmpty) {
            // Auto-select first chat in split view when data arrives.
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final failure = FailureMapper.from(e);
        _error = failure.message;
        _errorCorrelationId = failure.correlationId;
      }
    }
    if (mounted) setState(() => _loading = false);
    widget.onUnreadChanged?.call();
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

  List<UserPublic> get _friendsWithoutChat {
    final chatIds = _chats.map((c) => c.friend.id).toSet();
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

  String? _avatarUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return photoUrl;
    }
    if (photoUrl.startsWith('/')) return '$apiBaseUrl$photoUrl';
    return '$apiBaseUrl/$photoUrl';
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
    if (split) {
      setState(() => _selectedFriend = friend);
      return;
    }
    await Navigator.of(context).push(
      PrimeRoute.sharedAxis(
        builder: (_) => DirectChatScreen(friend: friend),
      ),
    );
    await _load();
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
        const AppSocialSectionHeader(title: 'Команда'),
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

  Widget _pageHeader({required bool split}) {
    if (split) {
      return Padding(
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
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Чаты',
                  style: KitTypography.pageTitle.copyWith(fontSize: 28),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Личные и командные сообщения',
                  style: KitTypography.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          NotificationBellButton(onOpenGroups: widget.onOpenGroups),
        ],
      ),
    );
  }

  Widget _inboxList({required bool split, EdgeInsets? padding}) {
    return ListView(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.bottomNavClearance,
          ),
      children: [
        if (!split) _pageHeader(split: false),
        if (split) _pageHeader(split: true),
        const SizedBox(height: AppSpacing.sm),
        _SegmentBar(
          value: _segment,
          onChanged: (v) => setState(() => _segment = v),
        ),
        if (_segment == _ChatsSegment.team) _teamSegment(split: split) else ...[
          AppSocialSectionHeader(
            title: 'Личные',
            actionLabel: AppCopy.findFriend,
            onAction: _openFriendSearchSheet,
          ),
          if (_chats.isEmpty)
            PrimeEmptyState(
              title: 'Пока нет переписки',
              body:
                  'Напишите другу из списка ниже или найдите человека по никнейму. '
                  'Чтобы пригласить в команду — выберите привычку.',
              actionLabel: AppCopy.findFriend,
              onAction: _openFriendSearchSheet,
              illustrationAsset: 'assets/illustrations/social.svg',
            )
          else
            for (final chat in _chats)
              _chatListRow(
                title: chat.friend.name.isEmpty
                    ? '@${chat.friend.nickname}'
                    : chat.friend.name,
                subtitle: (chat.lastMessageBody?.trim().isNotEmpty == true)
                    ? chat.lastMessageBody!.trim()
                    : (chat.friend.nickname.isEmpty
                        ? 'Нет сообщений'
                        : '@${chat.friend.nickname}'),
                initial: chat.friend.name.isNotEmpty
                    ? chat.friend.name[0].toUpperCase()
                    : (chat.friend.nickname.isNotEmpty
                        ? chat.friend.nickname[0].toUpperCase()
                        : '?'),
                avatarUrl: _avatarUrl(chat.friend.photoUrl),
                time: _formatChatTime(chat.lastMessageAt),
                unread: chat.unreadCount,
                onTap: () => _openChat(chat.friend, split: split),
              ),
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            onTap: _inviteFriendToTeam,
            padding: const EdgeInsets.all(AppSpacing.md),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            fillOpacity: 0.05,
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.primarySoft,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Пригласить друга в команду',
                    style: KitTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          if (_friendsWithoutChat.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppSocialSectionHeader(title: 'Друзья'),
            for (final friend in _friendsWithoutChat)
              _chatListRow(
                title: friend.name.isEmpty ? '@${friend.nickname}' : friend.name,
                subtitle: friend.nickname.isEmpty
                    ? 'Начать чат'
                    : '@${friend.nickname}',
                initial: friend.name.isNotEmpty
                    ? friend.name[0].toUpperCase()
                    : (friend.nickname.isNotEmpty
                        ? friend.nickname[0].toUpperCase()
                        : '?'),
                avatarUrl: _avatarUrl(friend.photoUrl),
                onTap: () => _openChat(friend, split: split),
              ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _chats.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: AmbientCanvas(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _pageHeader(split: false),
                ),
                const Expanded(child: AppChatListSkeleton()),
              ],
            ),
          ),
        ),
      );
    }
    if (_error != null && _chats.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: AmbientCanvas(
          child: AsyncErrorView(
            message: _error!,
            correlationId: _errorCorrelationId,
            onRetry: _load,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= AppBreakpoints.tablet;

        if (split) {
          final friend = _selectedFriend ??
              (_chats.isNotEmpty ? _chats.first.friend : null);
          return Scaffold(
            backgroundColor: AppColors.background,
            body: AmbientCanvas(
              child: Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _inboxList(
                        split: true,
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
                              widget.onUnreadChanged?.call();
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: AmbientCanvas(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _inboxList(split: false),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.value, required this.onChanged});

  final _ChatsSegment value;
  final ValueChanged<_ChatsSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: KitLayout.segmentHeight,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final seg in _ChatsSegment.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(seg),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: value == seg
                      ? BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    seg == _ChatsSegment.team ? 'Команда' : 'Личные',
                    textAlign: TextAlign.center,
                    style: KitTypography.caption.copyWith(
                      color: value == seg
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
