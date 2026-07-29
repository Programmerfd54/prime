import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import 'app_snackbar.dart';

/// Facade over Shad toaster with SnackBar fallback when toaster is absent
/// (e.g. isolated widget tests without ShadToaster ancestor).
abstract final class PrimeToast {
  static void show(
    BuildContext context,
    String message, {
    String? description,
    IconData icon = Icons.check_circle_outline_rounded,
    Duration duration = const Duration(seconds: 3),
  }) {
    final toaster = ShadToaster.maybeOf(context);
    if (toaster == null) {
      showAppSnackBar(context, message, duration: duration);
      return;
    }
    toaster.show(
      ShadToast(
        title: Text(message),
        description: description == null ? null : Text(description),
        duration: duration,
        backgroundColor: AppColors.elevatedSurface.withValues(alpha: 0.96),
        border: ShadBorder.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
        shadows: AppGlow.violet(opacity: 0.18),
        titleStyle: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        descriptionStyle: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  static void dayMarked(BuildContext context) => show(
        context,
        'День отмечен',
        description: 'Отчёт принят — команда видит ваш ритм',
        icon: Icons.task_alt_rounded,
      );

  static void inviteSent(BuildContext context) => show(
        context,
        'Приглашение отправлено',
        description: 'Друг получит уведомление в чатах',
        icon: Icons.person_add_alt_1_rounded,
      );
}
