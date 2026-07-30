import 'package:flutter/material.dart';

import '../../design/prime/prime_toast_overlay.dart';
import 'app_snackbar.dart';

/// Product toast helpers — V5 overlay via [showAppSnackBar].
abstract final class PrimeToast {
  static void show(
    BuildContext context,
    String message, {
    String? description,
    IconData icon = Icons.check_circle_outline_rounded,
    Duration duration = const Duration(seconds: 3),
  }) {
    final text = description == null ? message : '$message\n$description';
    showAppSnackBar(
      context,
      text,
      duration: duration,
      variant: PrimeToastVariant.success,
    );
  }

  static void dayMarked(BuildContext context) => showAppSnackBar(
        context,
        'День отмечен — отчёт принят, команда видит ваш ритм',
        variant: PrimeToastVariant.success,
      );

  static void inviteSent(BuildContext context) => showAppSnackBar(
        context,
        'Приглашение отправлено — друг получит уведомление',
        variant: PrimeToastVariant.success,
      );
}
