import 'package:flutter/material.dart';

import '../ui/states/app_error_state.dart';

/// Thin wrapper around [AppErrorState] — keeps the existing API.
class AsyncErrorView extends StatelessWidget {
  final String message;
  final String? correlationId;
  final Future<void> Function() onRetry;

  const AsyncErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.correlationId,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      message: message,
      correlationId: correlationId,
      onRetry: onRetry,
    );
  }
}
