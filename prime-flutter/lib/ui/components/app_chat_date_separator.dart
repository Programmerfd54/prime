import 'package:flutter/material.dart';

import '../../design/theme/prime_theme_context.dart';
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
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: p.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
