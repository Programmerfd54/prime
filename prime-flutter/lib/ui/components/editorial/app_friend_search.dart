import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/constants.dart';
import '../../../data/api_client.dart';
import '../../../design/routes.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../../../models/user.dart';
import '../../../screens/direct_chat_screen.dart';
import '../app_dialog.dart';
import '../app_primary_button.dart';
import '../app_search_field.dart';
import '../app_secondary_button.dart';
import '../app_snackbar.dart';
import '../profile/app_avatar.dart';
import '../profile/verified_email_badge.dart';

/// Applies friend-request API result to a nickname lookup payload (no re-fetch).
Map<String, dynamic> applyFriendRequestToLookup(
  Map<String, dynamic> foundUser,
  Map<String, dynamic> response,
) {
  final status = response['status'] as String? ?? 'pending';
  final requestId = response['request_id'] as String?;
  if (status == 'accepted') {
    return {
      ...foundUser,
      'is_friend': true,
      'has_pending_request': false,
      'pending_request_id': null,
      'pending_direction': null,
    };
  }
  return {
    ...foundUser,
    'has_pending_request': true,
    'pending_request_id': requestId,
    'pending_direction': 'outgoing',
  };
}

/// Opens friend search — state lives inside the sheet so results update live.
Future<void> showFriendSearchSheet(
  BuildContext context, {
  VoidCallback? onChanged,
}) {
  return showAppBottomSheet<void>(
    context: context,
    child: _FriendSearchSheet(onChanged: onChanged),
  );
}

class _FriendSearchSheet extends StatefulWidget {
  const _FriendSearchSheet({this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends State<_FriendSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _searchToken = 0;

  Map<String, dynamic>? _foundUser;
  bool _searching = false;
  bool _sendingRequest = false;
  bool _notFound = false;
  String? _error;

  static final _nicknamePattern = RegExp(r'^[a-z0-9_][a-z0-9_.-]{2,31}$');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  String _normalizedNickname(String raw) =>
      raw.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  String? _avatarUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return photoUrl;
    }
    if (photoUrl.startsWith('/')) return '$apiBaseUrl$photoUrl';
    return '$apiBaseUrl/$photoUrl';
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final nickname = _normalizedNickname(_controller.text);
    if (nickname.isEmpty) {
      setState(() {
        _foundUser = null;
        _notFound = false;
        _error = null;
        _searching = false;
      });
      return;
    }
    if (nickname.length < 3 || !_nicknamePattern.hasMatch(nickname)) {
      setState(() {
        _foundUser = null;
        _notFound = false;
        _error = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search({bool forceRefresh = false}) async {
    final nickname = _normalizedNickname(_controller.text);
    if (nickname.length < 3 || !_nicknamePattern.hasMatch(nickname)) return;

    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _notFound = false;
      _error = null;
      if (forceRefresh) _foundUser = null;
    });
    try {
      final result = await context.read<ApiClient>().findUserByNickname(
            nickname,
            forceRefresh: forceRefresh,
          );
      if (!mounted || token != _searchToken) return;
      setState(() {
        _foundUser = result;
        _notFound = result['user'] == null;
      });
    } on DioException catch (e) {
      if (!mounted || token != _searchToken) return;
      if (e.response?.statusCode == 404) {
        setState(() {
          _foundUser = null;
          _notFound = true;
        });
      } else {
        setState(() => _error = ApiClient.errorMessage(e));
      }
    } catch (e) {
      if (mounted && token == _searchToken) {
        setState(() => _error = ApiClient.errorMessage(e));
      }
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    final nickname = _normalizedNickname(_controller.text);
    if (nickname.isEmpty || _sendingRequest || _foundUser == null) return;
    setState(() => _sendingRequest = true);
    try {
      final result =
          await context.read<ApiClient>().sendFriendRequestByNickname(nickname);
      if (!mounted) return;
      setState(() {
        _foundUser = applyFriendRequestToLookup(_foundUser!, result);
      });
      final accepted = result['status'] == 'accepted';
      showAppSnackBar(
        context,
        accepted ? 'Теперь вы друзья — можно написать в чатах' : 'Заявка отправлена',
      );
      if (accepted) {
        widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _cancelFriendRequest() async {
    final requestId = _foundUser?['pending_request_id'] as String?;
    if (requestId == null || requestId.isEmpty) return;
    setState(() => _sendingRequest = true);
    try {
      await context.read<ApiClient>().cancelFriendRequest(requestId);
      if (!mounted) return;
      setState(() {
        _foundUser = {
          ...?_foundUser,
          'has_pending_request': false,
          'pending_request_id': null,
          'pending_direction': null,
        };
      });
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  void _writeToFoundFriend() {
    final user = _foundUser?['user'] as Map<String, dynamic>?;
    if (user == null) return;
    final friend = UserPublic.fromJson(user);
    unawaited(context.read<ApiClient>().warmDirectMessagesCache(friend.id));
    Navigator.of(context).pop();
    Navigator.of(context).push(
      PrimeRoute.sharedAxis(builder: (_) => DirectChatScreen(friend: friend)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _foundUser?['user'] as Map<String, dynamic>?;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppFriendSearchPanel(
          controller: _controller,
          foundUser: _foundUser,
          searching: _searching,
          sendingRequest: _sendingRequest,
          notFound: _notFound,
          error: _error,
          avatarUrl: _avatarUrl(user?['photo_url'] as String?),
          onSearch: () => _search(forceRefresh: true),
          onAddFriend: _sendFriendRequest,
          onCancelRequest: _cancelFriendRequest,
          onWrite: _writeToFoundFriend,
        ),
      ),
    );
  }
}

/// Friend search panel — editorial, not flat AppCard.
class AppFriendSearchPanel extends StatelessWidget {
  const AppFriendSearchPanel({
    super.key,
    required this.controller,
    required this.foundUser,
    required this.searching,
    required this.sendingRequest,
    required this.notFound,
    required this.error,
    required this.avatarUrl,
    required this.onSearch,
    required this.onAddFriend,
    required this.onCancelRequest,
    required this.onWrite,
  });

  final TextEditingController controller;
  final Map<String, dynamic>? foundUser;
  final bool searching;
  final bool sendingRequest;
  final bool notFound;
  final String? error;
  final String? avatarUrl;
  final VoidCallback onSearch;
  final VoidCallback onAddFriend;
  final VoidCallback onCancelRequest;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final user = foundUser?['user'] as Map<String, dynamic>?;
    final isSelf = foundUser?['is_self'] as bool? ?? false;
    final isFriend = foundUser?['is_friend'] as bool? ?? false;
    final hasPending = foundUser?['has_pending_request'] as bool? ?? false;
    final pendingOutgoing =
        hasPending && foundUser?['pending_direction'] == 'outgoing';
    final pendingIncoming =
        hasPending && foundUser?['pending_direction'] == 'incoming';
    final meta = [
      if ((user?['region_name'] as String? ?? '').isNotEmpty)
        user!['region_name'],
      if (user?['age'] != null) '${user!['age']} лет',
    ].join(' · ');
    final about = (user?['about'] as String? ?? '').trim();
    final name = user?['name'] as String? ?? 'Пользователь';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: AppColors.elevatedSurface,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Поиск друзей', style: AppTypography.title2),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Введите никнейм — результат появится автоматически.',
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
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        photoUrl: avatarUrl,
                        radius: 24,
                        name: name,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title2,
                            ),
                            if ((user['nickname'] as String? ?? '').isNotEmpty)
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '@${user['nickname']}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primarySoft,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user['email_verified'] as bool? ?? true) ...[
                                    const SizedBox(width: 4),
                                    const VerifiedEmailBadge(size: 14),
                                  ],
                                ],
                              ),
                            if (meta.isNotEmpty)
                              Text(meta, style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                  if (!isSelf) ...[
                    const SizedBox(height: AppSpacing.sm),
                    if (isFriend)
                      AppPrimaryButton(
                        label: AppCopy.writeMessage,
                        icon: Icons.chat_bubble_outline,
                        onPressed: onWrite,
                      )
                    else if (pendingOutgoing)
                      AppSecondaryButton(
                        label: 'Отменить заявку',
                        icon: Icons.close,
                        loading: sendingRequest,
                        onPressed: sendingRequest ? null : onCancelRequest,
                      )
                    else if (pendingIncoming)
                      const AppSecondaryButton(
                        label: 'Ждёт вашего ответа',
                        onPressed: null,
                      )
                    else
                      AppPrimaryButton(
                        label: 'Добавить в друзья',
                        icon: Icons.person_add_alt_1,
                        loading: sendingRequest,
                        onPressed: sendingRequest ? null : onAddFriend,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
