import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_typography.dart';

/// Inbox / settings row — flat surface, no glass wrapper.
class PrimeListRow extends StatelessWidget {
  const PrimeListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    this.onTap,
    this.dense = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? badge;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final height = dense ? KitLayout.listRowCompact : KitLayout.listRowHeight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KitTypography.cardTitle.copyWith(
                          color: p.ink,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: KitTypography.caption.copyWith(color: p.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: p.brand,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badge!,
                      style: KitTypography.caption.copyWith(color: p.inkOnBrand),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
