import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_typography.dart';

/// Expressive zero-state — illustration, title, one line, optional CTA.
class PrimeEmptyState extends StatelessWidget {
  const PrimeEmptyState({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.illustrationAsset = 'assets/illustrations/empty.svg',
  });

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String illustrationAsset;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            illustrationAsset,
            height: 120,
            colorFilter: ColorFilter.mode(p.brandSoft.withValues(alpha: 0.8), BlendMode.srcIn),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KitTypography.sectionTitle.copyWith(color: p.ink, fontSize: 20),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: p.brand,
                foregroundColor: p.inkOnBrand,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
