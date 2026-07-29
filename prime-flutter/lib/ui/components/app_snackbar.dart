import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Unified snackbar helper for transient feedback — glass floating surface.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      backgroundColor: AppColors.surface.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: AppColors.primary,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
