import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';

/// Verified email indicator — shown next to nickname or email.
class VerifiedEmailBadge extends StatelessWidget {
  const VerifiedEmailBadge({
    super.key,
    this.size = 16,
    this.tooltip = 'Email подтверждён',
  });

  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Tooltip(
      message: tooltip,
      child: Icon(
        Icons.verified,
        size: size,
        color: p.mint,
      ),
    );
  }
}

/// Name row with optional verified badge.
class VerifiedDisplayName extends StatelessWidget {
  const VerifiedDisplayName({
    super.key,
    required this.name,
    this.verified = false,
    this.style,
    this.badgeSize = 16,
    this.maxLines = 1,
  });

  final String name;
  final bool verified;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (verified) ...[
          const SizedBox(width: AppSpacing.xxs),
          VerifiedEmailBadge(size: badgeSize),
        ],
      ],
    );
  }
}
