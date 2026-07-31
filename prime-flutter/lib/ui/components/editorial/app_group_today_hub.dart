import 'package:flutter/material.dart';

import '../../../core/groups/group_member_today_status.dart';
import '../../../core/groups/progress_labels.dart';
import '../../../core/groups/team_day_presentation.dart';
import '../../../design/theme/prime_colors.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../l10n/copy.dart';
import '../../../models/group.dart';
import '../../kit/components/prime_content_card.dart';
import '../app_chip.dart';
import '../app_primary_button.dart';
import '../app_secondary_button.dart';
import '../profile/app_avatar.dart';

/// The active-cycle command center: one truth, one primary action, real people.
class AppGroupTodayHub extends StatelessWidget {
  const AppGroupTodayHub({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.reportSending,
    required this.checkInSending,
    required this.onReport,
    required this.onCheckIn,
    required this.onSupport,
    required this.onOpenChat,
    required this.onShowProgress,
    this.onReaction,
  });

  final GroupModel group;
  final String? currentUserId;
  final bool reportSending;
  final bool checkInSending;
  final VoidCallback onReport;
  final ValueChanged<String> onCheckIn;
  final ValueChanged<MemberModel> onSupport;
  final VoidCallback onOpenChat;
  final VoidCallback onShowProgress;
  final Future<void> Function(String messageId, String emoji)? onReaction;

  static const _reactionEmojis = ['💪', '✅'];

  MemberModel? get _me {
    for (final member in group.members) {
      if (member.userId == currentUserId) return member;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final active = group.members.where((member) => member.active).toList();
    final teamDay = TeamDayPresentationResolver.resolve(group);
    final ready = teamDay.ready;
    final total = teamDay.total;
    final teamComplete = teamDay.isComplete || (total > 0 && ready >= total);
    final me = _me;
    final myReportReady =
        me?.reportStatus == 'ready' || group.myTodayReport?.reported == true;
    final waiting = active
        .where(
          (member) =>
              member.userId != currentUserId && member.reportStatus != 'ready',
        )
        .toList();

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ProgressLabels.cycle(day: group.cycleDay),
                      style: AppTypography.title1.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      AppCopy.cycleContinuationFootnote,
                      style: AppTypography.caption.copyWith(color: p.inkMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      teamComplete
                          ? 'Сегодня команда закрыла день вместе'
                          : teamDay.label,
                      style: AppTypography.bodySecondary.copyWith(
                        color: teamComplete ? p.mint : p.inkSecondary,
                      ),
                    ),
                    if (!teamComplete) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        teamDay.closesAtLabel ??
                            _teamDayDeadlineLabel(group.teamDay),
                        style: AppTypography.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color:
                      (teamComplete ? p.mint : p.brand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: (teamComplete ? p.mint : p.brand)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '$ready/$total отчётов',
                  style: AppTypography.caption.copyWith(
                    color: teamComplete ? p.mint : p.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final member in active) ...[
            _TodayMemberRow(
              member: member,
              isMe: member.userId == currentUserId,
              onSupport: member.userId == currentUserId ||
                      member.reportStatus == 'ready'
                  ? null
                  : () => onSupport(member),
              onReaction: onReaction,
              reactionEmojis: _reactionEmojis,
            ),
            if (member != active.last) const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
          if (!myReportReady)
            AppPrimaryButton(
              label: reportSending ? 'Отправка…' : 'Отправить отчёт',
              icon: Icons.edit_note_rounded,
              loading: reportSending,
              onPressed: reportSending ? null : onReport,
            )
          else if (!teamComplete && waiting.isNotEmpty)
            AppPrimaryButton(
              label:
                  'Поддержать ${waiting.length} ${_peopleWord(waiting.length)}',
              icon: Icons.favorite_outline_rounded,
              onPressed: () => onSupport(waiting.first),
            )
          else if (teamComplete)
            AppPrimaryButton(
              label: 'День закрыт · +1 Прайм',
              icon: Icons.auto_awesome_rounded,
              success: true,
              onPressed: onShowProgress,
            )
          else
            AppPrimaryButton(
              label: 'Отчёт принят · команда видит вас',
              icon: Icons.check_circle_rounded,
              success: true,
              onPressed: onOpenChat,
            ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Чат команды',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: onOpenChat,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Как вы сегодня?',
            style: AppTypography.caption.copyWith(
              color: p.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusChip(
                label: 'Начинаю',
                kind: 'starting',
                selected: me?.checkInKind == 'starting',
                enabled: !checkInSending,
                onCheckIn: onCheckIn,
              ),
              _StatusChip(
                label: 'Выполнил',
                kind: 'done',
                selected: me?.checkInKind == 'done',
                enabled: !checkInSending,
                onCheckIn: onCheckIn,
              ),
              _StatusChip(
                label: 'Нужна поддержка',
                kind: 'support',
                selected: me?.checkInKind == 'support',
                enabled: !checkInSending,
                onCheckIn: onCheckIn,
              ),
              _StatusChip(
                label: 'Сегодня сложно',
                kind: 'hard',
                selected: me?.checkInKind == 'hard',
                enabled: !checkInSending,
                onCheckIn: onCheckIn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _peopleWord(int count) {
    if (count == 1) return 'участника';
    return 'участников';
  }

  static String _teamDayDeadlineLabel(TeamDayModel? teamDay) {
    final closesAt = teamDay?.closesAt;
    if (closesAt == null) {
      final tz = teamDay?.referenceTimezone;
      if (tz != null && tz.isNotEmpty) {
        return 'День команды · $tz';
      }
      return 'День команды';
    }
    final local = closesAt.toLocal();
    final remaining = local.difference(DateTime.now());
    if (remaining.isNegative) return 'День команды закрывается';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final tz = teamDay?.referenceTimezone;
    final tzLabel = tz != null && tz.isNotEmpty ? ' · $tz' : '';
    if (hours > 0) {
      return 'До закрытия дня: ${hours}ч ${minutes}м$tzLabel';
    }
    if (minutes > 0) {
      return 'До закрытия дня: ${minutes}м$tzLabel';
    }
    return 'День команды закрывается$tzLabel';
  }
}

class _TodayMemberRow extends StatelessWidget {
  const _TodayMemberRow({
    required this.member,
    required this.isMe,
    this.onSupport,
    this.onReaction,
    this.reactionEmojis = const [],
  });

  final MemberModel member;
  final bool isMe;
  final VoidCallback? onSupport;
  final Future<void> Function(String messageId, String emoji)? onReaction;
  final List<String> reactionEmojis;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final profile = member.profile;
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : profile?.nickname.trim().isNotEmpty == true
            ? '@${profile!.nickname}'
            : 'Участник';
    final todayStatus = GroupMemberTodayStatus.resolve(member);
    final color = _memberColor(todayStatus.tone, p);
    final messageId = member.lastReportMessageId;
    final showReactions = !isMe &&
        member.reportStatus == 'ready' &&
        messageId != null &&
        messageId.isNotEmpty &&
        onReaction != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceSoft.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(photoUrl: profile?.photoUrl, radius: 22, name: name),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: p.surfaceSoft, width: 2),
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
                    Text(
                      isMe ? '$name · вы' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      todayStatus.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (onSupport != null && todayStatus.needsSupport)
                IconButton(
                  tooltip: 'Поддержать',
                  onPressed: onSupport,
                  icon: Icon(
                    Icons.favorite_outline_rounded,
                    color: p.brand,
                    size: 21,
                  ),
                )
              else
                Icon(
                  todayStatus.reportReady
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: color,
                  size: 21,
                ),
            ],
          ),
          if (showReactions) ...[
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              children: [
                for (final emoji in reactionEmojis)
                  ActionChip(
                    label: Text(emoji),
                    onPressed: () => onReaction!(messageId, emoji),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _memberColor(GroupMemberTodayTone tone, PrimeColors p) {
    return switch (tone) {
      GroupMemberTodayTone.complete => p.mint,
      GroupMemberTodayTone.support => AppColors.achievementAmber,
      GroupMemberTodayTone.inProgress => p.brand,
      GroupMemberTodayTone.idle => p.inkMuted,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.kind,
    required this.selected,
    required this.enabled,
    required this.onCheckIn,
  });

  final String label;
  final String kind;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onCheckIn;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: selected ? '✓ $label' : label,
      onTap: enabled ? () => onCheckIn(kind) : null,
    );
  }
}
