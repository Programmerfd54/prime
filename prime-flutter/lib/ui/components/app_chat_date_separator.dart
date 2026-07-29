import 'package:flutter/material.dart';

import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Editorial date chip in chat timelines.
class AppChatDateSeparator extends StatelessWidget {
  const AppChatDateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(child: _DateChip(label: label)),
    );
  }
}

class AppChatStickyDateHeader extends StatelessWidget {
  const AppChatStickyDateHeader({super.key, required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null || label!.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: _DateChip(label: label!),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      fillOpacity: 0.06,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
