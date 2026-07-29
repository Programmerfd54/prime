import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../l10n/copy.dart';

class AppConnectionBanner extends StatelessWidget {
  const AppConnectionBanner({
    super.key,
    required this.visible,
    this.message = AppCopy.network,
    this.onRetry,
  });

  final bool visible;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Material(
      color: AppColors.warning.withValues(alpha: 0.16),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text(AppCopy.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
