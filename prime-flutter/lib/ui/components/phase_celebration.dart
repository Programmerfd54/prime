import 'package:flutter/material.dart';

import '../../design/lottie_registry.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

enum PhaseCelebrationKind {
  introToRules,
  rulesToActive,
  teamDayClosed,
}

Future<void> showPhaseCelebration(
  BuildContext context, {
  required PhaseCelebrationKind kind,
}) {
  final copy = switch (kind) {
    PhaseCelebrationKind.introToRules => (
        'Команда готова к договору',
        'Все подтвердили участие — примите командный договор',
      ),
    PhaseCelebrationKind.rulesToActive => (
        'Первый день открыт',
        'Договор принят всеми — команда видит ваши действия',
      ),
    PhaseCelebrationKind.teamDayClosed => (
        'День закрыт всей командой',
        '+1 Прайм каждому · вы сделали это вместе',
      ),
  };
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PrimeLottie(
                  slot: PrimeLottieSlot.success,
                  height: 120,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.$1,
                  textAlign: TextAlign.center,
                  style: AppTypography.title2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  copy.$2,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Продолжить'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
