import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../tokens.dart';
import '../../typography.dart';

enum HabitMood { energetic, calm, focused }

extension HabitMoodX on HabitMood {
  String get label => switch (this) {
        HabitMood.energetic => 'Энергично',
        HabitMood.calm => 'Спокойно',
        HabitMood.focused => 'Сфокусироваться',
      };

  IconData get icon => switch (this) {
        HabitMood.energetic => Icons.bolt_rounded,
        HabitMood.calm => Icons.spa_outlined,
        HabitMood.focused => Icons.center_focus_strong_outlined,
      };
}

/// Mood pills that temporarily reorder habit recommendations.
class PrimeMoodSwitcher extends StatelessWidget {
  const PrimeMoodSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Что подойдёт вам сегодня',
  });

  final HabitMood value;
  final ValueChanged<HabitMood> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.title2),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final mood in HabitMood.values) ...[
                _Pill(
                  mood: mood,
                  selected: mood == value,
                  onTap: () {
                    AppHaptics.selection();
                    onChanged(mood);
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final HabitMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: selected
                ? AppColors.surfaceLight
                : AppColors.elevatedSurface.withValues(alpha: 0.6),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mood.icon,
                size: 16,
                color: selected ? AppColors.primaryDeep : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                mood.label,
                style: AppTypography.caption.copyWith(
                  color: selected
                      ? AppColors.textOnLight
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
