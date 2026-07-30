import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/direct_chat.dart';
import '../../../models/user.dart';
import '../../../widgets/notification_bell_button.dart';
import '../../components/profile/verified_email_badge.dart';
import '../components/prime_content_card.dart';
import '../components/prime_empty_state.dart';
import '../components/prime_list_row.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_typography.dart';
import '../../components/profile/app_avatar.dart';

/// Chats inbox — team, personal, and people discovery segments.
class GateChatsPresentation extends StatelessWidget {
  const GateChatsPresentation({
    super.key,
    required this.chats,
    this.segmentIndex = 1,
    this.unreadCount = 0,
    this.onSegmentChanged,
    this.onFindFriend,
    this.onOpenPeople,
    this.onInviteLink,
    this.onChatTap,
    this.onOpenGroups,
    this.teamBody,
    this.peopleBody,
    this.includePeopleBody = true,
    this.friendsWithoutChat = const [],
    this.showPageHeader = true,
    this.timeLabelFor,
  });

  final List<DirectChatSummary> chats;
  final int segmentIndex;
  final int unreadCount;
  final ValueChanged<int>? onSegmentChanged;
  final VoidCallback? onFindFriend;
  final VoidCallback? onOpenPeople;
  final VoidCallback? onInviteLink;
  final ValueChanged<UserPublic>? onChatTap;
  final VoidCallback? onOpenGroups;
  final Widget? teamBody;
  final Widget? peopleBody;
  /// When false, only header + segment control render (people list is a sliver sibling).
  final bool includePeopleBody;
  final List<UserPublic> friendsWithoutChat;
  final bool showPageHeader;
  final String? Function(DateTime? at)? timeLabelFor;

  static const segmentLabels = ['Команда', 'Личные', 'Люди'];
  static const segmentIcons = [
    Icons.groups_2_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.people_outline_rounded,
  ];

  bool get _isPersonal => segmentIndex == 1;
  bool get _isPeople => segmentIndex == 2;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final unreadChats = chats.where((c) => c.unreadCount > 0).toList();
    final readChats = chats.where((c) => c.unreadCount == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPageHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Чаты', style: AppTypography.titleXL.copyWith(color: p.ink)),
                      const SizedBox(height: 4),
                      Text(
                        unreadCount > 0
                            ? '$unreadCount непрочитанных · команда и друзья'
                            : 'Команда, друзья и новые знакомства',
                        style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                NotificationBellButton(onOpenGroups: onOpenGroups),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ChatsSegmentControl(
            labels: segmentLabels,
            icons: segmentIcons,
            selectedIndex: segmentIndex,
            onSelected: onSegmentChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isPeople)
          includePeopleBody
              ? (peopleBody ?? const SizedBox.shrink())
              : const SizedBox.shrink()
        else if (!_isPersonal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: teamBody ??
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: PrimeEmptyState(
                    title: 'Команда ещё не собрана',
                    body: 'Сначала выберите привычку и соберите команду из 6.',
                  ),
                ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Личные', style: KitTypography.sectionTitle.copyWith(color: p.ink)),
                const Spacer(),
                TextButton(
                  onPressed: onOpenPeople ?? onFindFriend,
                  child: Text(
                    'Найти людей',
                    style: KitTypography.caption.copyWith(color: p.brand),
                  ),
                ),
              ],
            ),
          ),
          if (chats.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PrimeContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Начните с друзей',
                      style: KitTypography.sectionTitle.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Личные чаты помогают пригласить знакомых в команду.',
                      style: KitTypography.caption.copyWith(color: p.inkSecondary),
                    ),
                    if (friendsWithoutChat.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      for (final friend in friendsWithoutChat.take(4))
                        _PersonalChatRow(
                          friend: friend,
                          subtitle: 'Написать первым',
                          onTap: onChatTap != null ? () => onChatTap!(friend) : null,
                          timeLabelFor: timeLabelFor,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimeEmptyState(
                title: 'Пока нет переписки',
                body:
                    'Найдите людей во вкладке «Люди» или напишите другу из списка.',
                actionLabel: onOpenPeople != null ? 'Открыть людей' : null,
                onAction: onOpenPeople,
                illustrationAsset: 'assets/illustrations/social.svg',
              ),
            ),
          ] else ...[
            if (unreadChats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Непрочитанные',
                  style: KitTypography.caption.copyWith(
                    color: p.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final chat in unreadChats)
                _PersonalChatCard(
                  chat: chat,
                  onTap: onChatTap != null ? () => onChatTap!(chat.friend) : null,
                  timeLabelFor: timeLabelFor,
                ),
            ],
            if (readChats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 4),
                child: Text(
                  unreadChats.isEmpty ? 'Все чаты' : 'Остальные',
                  style: KitTypography.caption.copyWith(color: p.inkMuted),
                ),
              ),
              for (final chat in readChats)
                _PersonalChatCard(
                  chat: chat,
                  onTap: onChatTap != null ? () => onChatTap!(chat.friend) : null,
                  timeLabelFor: timeLabelFor,
                ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PrimeContentCard(
              onTap: onInviteLink,
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: p.brand, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Пригласить друга в команду',
                      style: KitTypography.cardTitle.copyWith(color: p.ink, fontSize: 15),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                ],
              ),
            ),
          ),
          if (friendsWithoutChat.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Друзья без чата',
                style: KitTypography.sectionTitle.copyWith(color: p.ink),
              ),
            ),
            for (final friend in friendsWithoutChat)
              _PersonalChatRow(
                friend: friend,
                subtitle: friend.nickname.isEmpty ? 'Начать чат' : '@${friend.nickname}',
                onTap: onChatTap != null ? () => onChatTap!(friend) : null,
                timeLabelFor: timeLabelFor,
              ),
          ],
        ],
        SizedBox(height: KitLayout.dockScrollTail(context)),
      ],
    );
  }

  static String formatChatTimeLabel(
    DateTime? at, [
    String? Function(DateTime? at)? custom,
  ]) {
    if (custom != null) return custom(at) ?? '';
    if (at == null) return '';
    final local = at.toLocal();
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
}

class _PersonalChatCard extends StatelessWidget {
  const _PersonalChatCard({
    required this.chat,
    this.onTap,
    this.timeLabelFor,
  });

  final DirectChatSummary chat;
  final VoidCallback? onTap;
  final String? Function(DateTime? at)? timeLabelFor;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final friend = chat.friend;
    final title = friend.name.isEmpty ? '@${friend.nickname}' : friend.name;
    final subtitle = (chat.lastMessageBody?.trim().isNotEmpty == true)
        ? chat.lastMessageBody!.trim()
        : 'Начните переписку';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: PrimeContentCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  name: friend.name,
                  photoUrl: friend.photoUrl,
                  radius: 26,
                ),
                if (chat.unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                        style: KitTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerifiedDisplayName(
                    name: title,
                    verified: friend.emailVerified,
                    style: KitTypography.cardTitle.copyWith(
                      color: p.ink,
                      fontSize: 15,
                      fontWeight:
                          chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KitTypography.caption.copyWith(
                      color: chat.unreadCount > 0 ? p.ink : p.inkMuted,
                      fontWeight:
                          chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              GateChatsPresentation.formatChatTimeLabel(
                chat.lastMessageAt,
                timeLabelFor,
              ),
              style: KitTypography.caption.copyWith(color: p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalChatRow extends StatelessWidget {
  const _PersonalChatRow({
    required this.friend,
    required this.subtitle,
    this.onTap,
    this.timeLabelFor,
  });

  final UserPublic friend;
  final String subtitle;
  final VoidCallback? onTap;
  final String? Function(DateTime? at)? timeLabelFor;

  @override
  Widget build(BuildContext context) {
    final title = friend.name.isEmpty ? '@${friend.nickname}' : friend.name;
    return PrimeListRow(
      leading: AppAvatar(
        name: friend.name,
        photoUrl: friend.photoUrl,
        radius: 24,
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

/// Segmented control for chats tabs with optional icons.
class ChatsSegmentControl extends StatelessWidget {
  const ChatsSegmentControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.icons = const [],
    this.onSelected,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      height: KitLayout.segmentHeight + 4,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
        boxShadow: [
          BoxShadow(
            color: p.brand.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: onSelected != null ? () => onSelected!(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? p.brandContainer.withValues(alpha: 0.55)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: i == selectedIndex
                        ? Border.all(color: p.brand.withValues(alpha: 0.25))
                        : null,
                    boxShadow: i == selectedIndex
                        ? [
                            BoxShadow(
                              color: p.brand.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i < icons.length) ...[
                        Icon(
                          icons[i],
                          size: 16,
                          color: i == selectedIndex ? p.brand : p.inkMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KitTypography.caption.copyWith(
                            color: i == selectedIndex ? p.ink : p.inkMuted,
                            fontWeight:
                                i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Demo chat row data for gate tests.
DirectChatSummary gateDemoChat(UserPublic friend, {String? body, int unread = 0}) {
  return DirectChatSummary(
    friend: friend,
    lastMessageBody: body ?? 'Привет! Как прошёл check-in?',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
    unreadCount: unread,
  );
}
