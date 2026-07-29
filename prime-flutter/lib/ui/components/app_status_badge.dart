import 'package:flutter/material.dart';

import '../../design/tokens.dart';

enum AppStatusBadgeTone { neutral, success, warning, error, info }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusBadgeTone.neutral,
  });

  final String label;
  final AppStatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppStatusBadgeTone.success => AppColors.success,
      AppStatusBadgeTone.warning => AppColors.warning,
      AppStatusBadgeTone.error => AppColors.error,
      AppStatusBadgeTone.info => AppColors.information,
      AppStatusBadgeTone.neutral => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
