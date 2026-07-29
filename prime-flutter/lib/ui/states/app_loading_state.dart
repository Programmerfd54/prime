import 'package:flutter/material.dart';

import '../../design/lottie_registry.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PrimeLottie(
            slot: PrimeLottieSlot.loading,
            width: 96,
            height: 96,
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
          ],
        ],
      ),
    );
  }
}
