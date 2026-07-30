import 'package:flutter/material.dart';

import '../../../design/prime/prime_glass_surface.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

class PrimeActionMenuItem {
  const PrimeActionMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

/// V5 dark-glass action menu for burger buttons.
Future<void> showPrimeActionMenu({
  required BuildContext context,
  required List<PrimeActionMenuItem> items,
  Offset? position,
  RelativeRect? anchor,
}) {
  final p = context.prime;
  return showMenu<void>(
    context: context,
    color: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    position: anchor ??
        RelativeRect.fromLTRB(
          position?.dx ?? 16,
          position?.dy ?? 16,
          16,
          16,
        ),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: PrimeGlassSurface(
          variant: PrimeGlassVariant.contextMenu,
          radius: AppRadius.lg,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.hairline),
                _MenuRow(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final PrimeActionMenuItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final color = !item.enabled
        ? p.inkMuted
        : item.destructive
            ? p.coral
            : p.ink;
    return InkWell(
      onTap: item.enabled
          ? () {
              Navigator.of(context).pop();
              item.onTap();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                item.label,
                style: AppTypography.body.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
