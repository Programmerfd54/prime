import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../l10n/copy.dart';
import '../../ui/states/app_error_state.dart';

/// Installs global Flutter / platform error handlers and a branded ErrorWidget.
///
/// Call this inside the same zone as [runApp] (see `main.dart`).
void installAppErrorBoundary() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught: $error\n$stack');
    }
    return true;
  };

  ErrorWidget.builder = (details) {
    // When a tiny leaf (chart cell, chip, icon button) fails, never inject the
    // full-page error UI — that causes multi-hundred-pixel RenderFlex overflows.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = !constraints.hasBoundedHeight ||
            !constraints.hasBoundedWidth ||
            constraints.maxHeight < 140 ||
            constraints.maxWidth < 140;

        if (tight) {
          return ColoredBox(
            color: AppColors.error.withValues(alpha: 0.18),
            child: Center(
              child: Icon(
                Icons.error_outline,
                size: 14,
                color: AppColors.error,
              ),
            ),
          );
        }

        final code = details.hashCode.toRadixString(16);
        return Material(
          color: AppColors.background,
          child: AppErrorState(
            message: AppCopy.unexpectedError,
            correlationId: 'ui-$code',
          ),
        );
      },
    );
  };
}
