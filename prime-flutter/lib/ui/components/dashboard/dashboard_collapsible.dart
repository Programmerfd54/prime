import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// Dark collapsible section for dashboard secondary blocks.
class DashboardCollapsibleSection extends StatelessWidget {
  const DashboardCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.92),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          iconColor: AppColors.primarySoft,
          collapsedIconColor: AppColors.textMuted,
          title: Text(title, style: AppTypography.title2),
          children: [child],
        ),
      ),
    );
  }
}
