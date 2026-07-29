import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_surfaces.dart';
import '../tokens/kit_typography.dart';

/// Brand-forward CTA / hero card — one focal message + action.
class PrimeAccentCard extends StatelessWidget {
  const PrimeAccentCard({
    super.key,
    required this.title,
    this.body,
    this.leading,
    this.actionLabel,
    this.onAction,
    this.accent = KitAccent.brand,
  });

  final String title;
  final String? body;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final KitAccent accent;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: kitSurfaceDecoration(
        context,
        PrimeSurfaceLevel.accent,
        radius: AppRadius.xl,
        accent: accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(height: AppSpacing.sm)],
          Text(
            title,
            style: KitTypography.sectionTitle.copyWith(color: p.ink, fontSize: 20),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              body!,
              style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: p.brand,
                foregroundColor: p.inkOnBrand,
                minimumSize: const Size.fromHeight(AppControlHeights.buttonCompact),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(actionLabel!, style: KitTypography.chip),
            ),
          ],
        ],
      ),
    );
  }
}
