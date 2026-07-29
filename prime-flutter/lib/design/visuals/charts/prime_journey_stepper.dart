import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../../typography.dart';

enum JourneyStepStatus { done, current, upcoming }

class JourneyStep {
  const JourneyStep({
    required this.label,
    required this.status,
    this.icon,
  });

  final String label;
  final JourneyStepStatus status;
  final IconData? icon;
}

/// Interactive Habit → Team → First day stepper.
class PrimeJourneyStepper extends StatelessWidget {
  const PrimeJourneyStepper({
    super.key,
    required this.steps,
    this.onStepTap,
  });

  final List<JourneyStep> steps;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: steps[i - 1].status == JourneyStepStatus.done
                    ? AppColors.primary
                    : AppColors.borderStrong,
              ),
            ),
          Flexible(
            child: _StepNode(
              step: steps[i],
              index: i,
              onTap: onStepTap == null ? null : () => onStepTap!(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.index,
    this.onTap,
  });

  final JourneyStep step;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color ring;
    final Color fill;
    final Widget icon;
    switch (step.status) {
      case JourneyStepStatus.done:
        ring = AppColors.success;
        fill = AppColors.success.withValues(alpha: 0.2);
        icon = Icon(Icons.check_rounded, size: 16, color: AppColors.success);
      case JourneyStepStatus.current:
        ring = AppColors.primary;
        fill = AppColors.primary.withValues(alpha: 0.25);
        icon = Icon(
          step.icon ?? Icons.circle,
          size: 12,
          color: AppColors.primarySoft,
        );
      case JourneyStepStatus.upcoming:
        ring = AppColors.borderStrong;
        fill = AppColors.elevatedSurface;
        icon = Text(
          '${index + 1}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: ring, width: 2),
              boxShadow: step.status == JourneyStepStatus.current
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: step.status == JourneyStepStatus.upcoming
                    ? AppColors.textMuted
                    : AppColors.textSecondary,
                fontWeight: step.status == JourneyStepStatus.current
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
