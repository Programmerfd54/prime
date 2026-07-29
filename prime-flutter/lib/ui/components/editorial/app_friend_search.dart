import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../app_primary_button.dart';
import '../app_search_field.dart';
import '../app_secondary_button.dart';
import '../profile/app_avatar.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentSurface.withValues(alpha: 0.35),
            AppColors.surfaceSoft.withValues(alpha: 0.65),
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Поиск друзей', style: AppTypography.title2),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Введите никнейм, чтобы найти человека и отправить заявку.',
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
                              Text(
                                '@${user['nickname']}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primarySoft,
                                ),
                              ),
                            if (meta.isNotEmpty)
                              Text(meta, style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
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
