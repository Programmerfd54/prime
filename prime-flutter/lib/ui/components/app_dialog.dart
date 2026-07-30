import 'package:flutter/material.dart';

import '../../design/prime/prime_glass_surface.dart';
import '../../design/haptics.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

Future<void> showAppInfoDialog({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = 'Понятно',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: PrimeGlassSurface(
        variant: PrimeGlassVariant.contextMenu,
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.title1),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppTypography.bodySecondary),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = 'OK',
  String cancelLabel = 'Отмена',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: PrimeGlassSurface(
        variant: PrimeGlassVariant.contextMenu,
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.title1),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppTypography.bodySecondary),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    cancelLabel,
                    style: AppTypography.button.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (destructive) {
                      AppHaptics.warning();
                    } else {
                      AppHaptics.selection();
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    confirmLabel,
                    style: AppTypography.button.copyWith(
                      color:
                          destructive ? AppColors.error : AppColors.primarySoft,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: PrimeGlassSurface(
        variant: PrimeGlassVariant.sheet,
        padding: EdgeInsets.zero,
        radius: AppRadius.xl,
        child: child,
      ),
    ),
  );
}
