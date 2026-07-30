import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/user.dart';
import '../../components/profile/app_avatar.dart';
import '../tokens/kit_typography.dart';

/// V4 Visual Gate — direct conversation (filled messages).
class GateConversationPresentation extends StatelessWidget {
  const GateConversationPresentation({
    super.key,
    required this.friend,
    this.messages = const [],
    this.showQuickReplies = true,
  });

  final UserPublic friend;
  final List<GateMessage> messages;
  final bool showQuickReplies;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      children: [
        _ConversationAppBar(friend: friend),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              _DateDivider(label: '27.07.2026'),
              for (final msg in messages) _MessageBubble(message: msg),
            ],
          ),
        ),
        if (showQuickReplies) const _QuickReplies(),
        _Composer(),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class GateMessage {
  const GateMessage({
    required this.body,
    required this.outbound,
    this.time = '01:08',
    this.read = true,
  });

  final String body;
  final bool outbound;
  final String time;
  final bool read;
}

class _ConversationAppBar extends StatelessWidget {
  const _ConversationAppBar({required this.friend, this.onBack, this.onTitleTap});

  final UserPublic friend;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 4, 12, 10),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.ink, size: 20),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Row(
                children: [
                  AppAvatar(name: friend.name, photoUrl: friend.photoUrl, radius: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.name.isEmpty ? '@${friend.nickname}' : friend.name,
                          style: AppTypography.title2.copyWith(color: p.ink, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${friend.nickname}',
                          style: KitTypography.caption.copyWith(color: p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: p.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.hairline),
          ),
          child: Text(label, style: KitTypography.caption.copyWith(color: p.inkMuted)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final GateMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final align = message.outbound ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.outbound ? p.bubbleOutbound : p.bubbleInbound;
    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.outbound ? 18 : 6),
            bottomRight: Radius.circular(message.outbound ? 6 : 18),
          ),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.body,
                style: AppTypography.body.copyWith(color: p.ink),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: KitTypography.caption.copyWith(color: p.inkMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies();

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    const labels = ['Отчёт готов', 'Поддерживаю', 'Как прошло?'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.hairline),
            ),
            child: Text(
              labels[i],
              style: KitTypography.caption.copyWith(color: p.inkSecondary),
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_rounded, color: p.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: p.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.hairline),
              ),
              child: Text(
                'Сообщение',
                style: KitTypography.caption.copyWith(color: p.inkMuted),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.brand,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.arrow_upward_rounded, color: p.inkOnBrand, size: 22),
          ),
        ],
      ),
    );
  }
}

/// V4 skeleton conversation for loading gate.
class GateConversationSkeleton extends StatelessWidget {
  const GateConversationSkeleton({super.key, required this.friend});

  final UserPublic friend;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      children: [
        _ConversationAppBar(friend: friend),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < 6; i++)
                Align(
                  alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: i.isEven ? 180 : 140,
                    height: 44,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: p.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
