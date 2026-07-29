import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

/// Compact form-level error message.
class AppInlineError extends StatelessWidget {
  const AppInlineError({
    super.key,
    required this.message,
    this.textAlign = TextAlign.center,
  });

  final String message;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        message,
        textAlign: textAlign,
        style: AppTypography.bodyMuted.copyWith(
          color: AppColors.error,
          fontSize: 13,
        ),
      ),
    );
  }
}
