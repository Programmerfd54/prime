import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Shown when native push registration is unavailable (Android without FCM, etc.).
class AppPushDegradedBanner extends StatelessWidget {
  const AppPushDegradedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, size: 18),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text(
              'Push недоступны на этом устройстве — используем обновления в приложении.',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}
