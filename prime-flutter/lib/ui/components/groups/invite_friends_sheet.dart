import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../data/api_client.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../../../models/user.dart';
import '../app_compact_button.dart';
import '../app_dialog.dart';
import '../app_primary_button.dart';
import '../app_search_field.dart';
import '../app_secondary_button.dart';
import '../app_snackbar.dart';
import '../profile/app_avatar.dart';

/// Opens a bottom sheet to invite friends into a waiting-room pair.
Future<void> showInviteFriendsSheet(
  BuildContext context, {
  required String skillId,
  required String skillName,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: _InviteFriendsSheet(
      skillId: skillId,
      skillName: skillName,
    ),
  );
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({
    required this.skillId,
    required this.skillName,
  });

  final String skillId;
  final String skillName;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final _nicknameCtrl = TextEditingController();
  final _selectedIds = <String>{};
  final _invitingIds = <String>{};

  List<UserPublic> _friends = [];
  bool _loading = true;
  bool _sendingBatch = false;
  bool _copyingLink = false;
  bool _searching = false;
  bool _sendingRequest = false;
  bool _notFound = false;
  String? _error;
  String? _searchError;
  Map<String, dynamic>? _foundUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFriends());
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context.read<ApiClient>().listFriends();
      if (!mounted) return;
      setState(() {
        _friends = rows
            .whereType<Map>()
            .map((row) => UserPublic.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = FailureMapper.from(e).message;
      });
    }
  }

  Future<void> _inviteUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;
    final ids = userIds.where((id) => !_invitingIds.contains(id)).toList();
    if (ids.isEmpty) return;

    setState(() {
      _invitingIds.addAll(ids);
      if (ids.length > 1) _sendingBatch = true;
    });
    try {
      final result = await context.read<ApiClient>().sendWaitingRoomPairInvites(
            skillId: widget.skillId,
            userIds: ids,
          );
      if (!mounted) return;
      final sent = (result['sent'] as List<dynamic>? ?? []).length;
      final skipped = (result['skipped'] as List<dynamic>? ?? []).length;
      if (sent > 0) {
        showAppSnackBar(
          context,
          sent == 1
              ? 'Приглашение отправлено'
              : 'Приглашения отправлены: $sent',
        );
        setState(() {
          _selectedIds.removeAll(ids);
        });
      } else if (skipped > 0) {
        showAppSnackBar(context, 'Не удалось отправить приглашение');
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) {
        setState(() {
          _invitingIds.removeAll(ids);
          _sendingBatch = false;
        });
      }
    }
  }

  Future<void> _copyInviteLink() async {
    if (_copyingLink) return;
    setState(() => _copyingLink = true);
    try {
      final result = await context
          .read<ApiClient>()
          .createWaitingRoomPairInvite(widget.skillId);
      final deepLink = result['deep_link'] as String? ?? '';
      final inviteCode = result['invite_code'] as String? ?? deepLink;
      await Clipboard.setData(
        ClipboardData(text: deepLink.isNotEmpty ? deepLink : inviteCode),
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Ссылка для пары скопирована — отправьте другу',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _copyingLink = false);
    }
  }

  Future<void> _searchFriend() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) return;
    setState(() {
      _searching = true;
      _notFound = false;
      _searchError = null;
      _foundUser = null;
    });
    try {
      final result =
          await context.read<ApiClient>().findUserByNickname(nickname);
      if (!mounted) return;
      setState(() {
        _foundUser = result;
        _notFound = result['user'] == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty || _sendingRequest) return;
    setState(() => _sendingRequest = true);
    try {
      await context.read<ApiClient>().sendFriendRequestByNickname(nickname);
      if (!mounted) return;
      showAppSnackBar(context, 'Заявка отправлена');
      await _searchFriend();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, FailureMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  void _toggleSelected(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppCopy.inviteFriend, style: AppTypography.title1),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Привычка «${widget.skillName}» — пригласите друга в пару, пока ищете команду.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Text(_error!, style: AppTypography.bodySecondary),
                    const SizedBox(height: AppSpacing.sm),
                    AppSecondaryButton(
                      label: AppCopy.retry,
                      onPressed: _loadFriends,
                    ),
                  ],
                ),
              )
            else if (_friends.isEmpty)
              _EmptyFriendsBody(
                controller: _nicknameCtrl,
                foundUser: _foundUser,
                searching: _searching,
                sendingRequest: _sendingRequest,
                notFound: _notFound,
                error: _searchError,
                copyingLink: _copyingLink,
                onSearch: _searchFriend,
                onAddFriend: _sendFriendRequest,
                onCopyLink: _copyInviteLink,
              )
            else ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final selected = _selectedIds.contains(friend.id);
                    final inviting = _invitingIds.contains(friend.id);
                    final display = friend.name.trim().isNotEmpty
                        ? friend.name
                        : '@${friend.nickname}';
                    return _FriendInviteRow(
                      name: display,
                      nickname: friend.nickname,
                      photoUrl: friend.photoUrl,
                      selected: selected,
                      inviting: inviting,
                      onToggle: () => _toggleSelected(friend.id),
                      onInvite: inviting
                          ? null
                          : () => _inviteUsers([friend.id]),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_selectedIds.isNotEmpty) ...[
                AppPrimaryButton(
                  label: 'Пригласить выбранных (${_selectedIds.length})',
                  icon: Icons.send_outlined,
                  loading: _sendingBatch,
                  onPressed: _sendingBatch
                      ? null
                      : () => _inviteUsers(_selectedIds.toList()),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppSecondaryButton(
                label: 'Скопировать ссылку',
                icon: Icons.link,
                loading: _copyingLink,
                onPressed: _copyingLink ? null : _copyInviteLink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FriendInviteRow extends StatelessWidget {
  const _FriendInviteRow({
    required this.name,
    required this.nickname,
    required this.photoUrl,
    required this.selected,
    required this.inviting,
    required this.onToggle,
    required this.onInvite,
  });

  final String name;
  final String nickname;
  final String? photoUrl;
  final bool selected;
  final bool inviting;
  final VoidCallback onToggle;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : null,
                ),
                side: BorderSide(color: AppColors.border, width: 1.4),
                visualDensity: VisualDensity.compact,
              ),
              AppAvatar(photoUrl: photoUrl, radius: 20, name: name),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (nickname.isNotEmpty)
                      Text(
                        '@$nickname',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primarySoft,
                        ),
                      ),
                  ],
                ),
              ),
              AppCompactButton(
                label: inviting ? '…' : 'Пригласить',
                loading: inviting,
                onPressed: onInvite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFriendsBody extends StatelessWidget {
  const _EmptyFriendsBody({
    required this.controller,
    required this.foundUser,
    required this.searching,
    required this.sendingRequest,
    required this.notFound,
    required this.error,
    required this.copyingLink,
    required this.onSearch,
    required this.onAddFriend,
    required this.onCopyLink,
  });

  final TextEditingController controller;
  final Map<String, dynamic>? foundUser;
  final bool searching;
  final bool sendingRequest;
  final bool notFound;
  final String? error;
  final bool copyingLink;
  final VoidCallback onSearch;
  final VoidCallback onAddFriend;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final user = foundUser?['user'] as Map<String, dynamic>?;
    final isSelf = foundUser?['is_self'] as bool? ?? false;
    final isFriend = foundUser?['is_friend'] as bool? ?? false;
    final hasPending = foundUser?['has_pending_request'] as bool? ?? false;
    final name = user?['name'] as String? ?? 'Пользователь';
    final nickname = user?['nickname'] as String? ?? '';
    final photoUrl = user?['photo_url'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Пока нет друзей. Найдите по никнейму или отправьте ссылку.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSearchField(
          controller: controller,
          keyboardType: TextInputType.visiblePassword,
          prefixText: '@',
          label: 'Никнейм друга',
          hint: 'например, dondonnik',
          maxLength: 32,
          searching: searching,
          onSearch: onSearch,
        ),
        if (notFound)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Пользователь не найден. Проверьте никнейм и попробуйте снова.',
              style: AppTypography.bodySecondary,
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              error!,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        if (user != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AppAvatar(photoUrl: photoUrl, radius: 22, name: name),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.title2),
                      if (nickname.isNotEmpty)
                        Text(
                          '@$nickname',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primarySoft,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isSelf)
                  AppCompactButton(
                    label: isFriend
                        ? 'Уже в друзьях'
                        : hasPending
                            ? 'Заявка отправлена'
                            : 'Добавить',
                    onPressed: isFriend || hasPending || sendingRequest
                        ? null
                        : onAddFriend,
                    loading: sendingRequest,
                    primary: !isFriend && !hasPending,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'Скопировать ссылку',
          icon: Icons.link,
          loading: copyingLink,
          onPressed: copyingLink ? null : onCopyLink,
        ),
      ],
    );
  }
}
