import 'package:flutter/material.dart';

import '../../kit/components/prime_content_card.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../models/group.dart';
import '../app_chip.dart';

/// Team rhythm block — uses real [TeamPulseModel] from API.
class AppGroupPulsePanel extends StatelessWidget {
  const AppGroupPulsePanel({
    super.key,
    required this.pulse,
    required this.onCheckIn,
    this.sending = false,
    this.actionWindow,
  });

  final TeamPulseModel pulse;
  final ValueChanged<String> onCheckIn;
  final bool sending;
  final String? actionWindow;

  @override
  Widget build(BuildContext context) {
    final accent = switch (pulse.status) {
      TeamPulseStatus.allDone => AppColors.success,
      TeamPulseStatus.high => AppColors.primarySoft,
      TeamPulseStatus.support => AppColors.achievementAmber,
      _ => AppColors.textSecondary,
    };

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: accent, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Командный ритм',
                  style: AppTypography.title2.copyWith(color: context.prime.ink),
                ),
              ),
              if (pulse.totalActive > 0)
                Text(
                  '${pulse.completedToday}/${pulse.totalActive}',
                  style: AppTypography.title2.copyWith(color: accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            pulse.message,
            style: AppTypography.bodySecondary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionWindow != null && actionWindow!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'в вашем окне · $actionWindow',
              style: AppTypography.caption.copyWith(color: AppColors.primarySoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _CheckInChip(
                label: 'Выполнил',
                kind: 'done',
                enabled: !sending,
                onTap: onCheckIn,
              ),
              _CheckInChip(
                label: 'Начинаю',
                kind: 'starting',
                enabled: !sending,
                onTap: onCheckIn,
              ),
              _CheckInChip(
                label: 'Нужна поддержка',
                kind: 'support',
                enabled: !sending,
                onTap: onCheckIn,
              ),
              _CheckInChip(
                label: 'Сегодня сложно',
                kind: 'hard',
                enabled: !sending,
                onTap: onCheckIn,
              ),
            ],
          ),
          if (pulse.checkIns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Check-in сегодня', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xxs),
            for (final item in pulse.checkIns.take(4))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  '@${item.nickname} — ${_kindLabel(item.kind)}',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _kindLabel(String kind) => switch (kind) {
        'done' => 'выполнил',
        'starting' => 'начинаю',
        'support' => 'нужна поддержка',
        'hard' => 'сегодня сложно',
        _ => kind,
      };
}

class _CheckInChip extends StatelessWidget {
  const _CheckInChip({
    required this.label,
    required this.kind,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final String kind;
  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      onTap: enabled ? () => onTap(kind) : null,
    );
  }
}
