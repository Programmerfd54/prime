import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_typography.dart';
import 'prime_glass_overlay.dart';

/// Sticky contextual CTA bar — measured height for scroll clearance.
class PrimeContextualActionBar extends StatelessWidget {
  const PrimeContextualActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.hint,
    this.caption,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? hint;
  final String? caption;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  static double heightFor(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return KitLayout.contextualBarMin + bottom + AppSpacing.md;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: PrimeGlassOverlay(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm + bottom * 0.25,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hint != null) ...[
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: KitTypography.caption.copyWith(color: p.inkSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Row(
                children: [
                  if (secondaryLabel != null && onSecondary != null) ...[
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: primaryIcon != null
                        ? FilledButton.icon(
                            onPressed: onPrimary,
                            icon: Icon(primaryIcon, size: 20),
                            label: Text(primaryLabel, style: KitTypography.chip),
                            style: FilledButton.styleFrom(
                              backgroundColor: p.brand,
                              foregroundColor: p.inkOnBrand,
                              minimumSize: const Size.fromHeight(
                                AppControlHeights.buttonCompact,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.button),
                              ),
                            ),
                          )
                        : FilledButton(
                            onPressed: onPrimary,
                            style: FilledButton.styleFrom(
                              backgroundColor: p.brand,
                              foregroundColor: p.inkOnBrand,
                              minimumSize: const Size.fromHeight(
                                AppControlHeights.buttonCompact,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.button),
                              ),
                            ),
                            child: Text(primaryLabel, style: KitTypography.chip),
                          ),
                  ),
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: KitTypography.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
