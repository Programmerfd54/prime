import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/copy.dart';
import '../../models/direct_chat.dart';
import '../../ui/components/editorial/app_social_inbox.dart';
import '../../ui/states/app_empty_state.dart';
import '../direct_chat_screen.dart';

class DirectChatsSection extends StatelessWidget {
  final List<DirectChatSummary> chats;
  final VoidCallback onFindFriend;
  final VoidCallback? onOpenAllChats;
  final Future<void> Function() onChatClosed;

  const DirectChatsSection({
    super.key,
    required this.chats,
    required this.onFindFriend,
    required this.onChatClosed,
    this.onOpenAllChats,
  });

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Личные чаты', style: AppTypography.title1),
            ),
            if (onOpenAllChats != null)
              TextButton(
                onPressed: onOpenAllChats,
                child: const Text('Все чаты'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (chats.isEmpty)
          AppEmptyState(
            title: 'Пока нет личных чатов',
            subtitle: 'Найдите друга по никнейму — после заявки можно написать.',
            actionLabel: AppCopy.findFriend,
            onAction: onFindFriend,
            icon: Icons.forum_outlined,
          )
        else ...[
          for (final chat
              in chats.take(onOpenAllChats != null ? 3 : chats.length))
            AppSocialInboxRow(
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
              onTap: () async {
                await Navigator.of(context).push(
                  PrimeRoute.sharedAxis(
                    builder: (_) => DirectChatScreen(friend: chat.friend),
                  ),
                );
                await onChatClosed();
              },
            ),
        ],
      ],
    );
  }
}
