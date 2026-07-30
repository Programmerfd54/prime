import 'package:flutter/material.dart';

import '../../design/prime/prime_toast_overlay.dart';
import '../../design/tokens.dart';

/// Unified transient feedback — V5 [PrimeToast] overlay with smart variant inference.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  PrimeToastVariant? variant,
}) {
  PrimeToastOverlay.show(
    context,
    message,
    variant: variant ?? _inferVariant(message),
    duration: duration,
    action: actionLabel != null && onAction != null
        ? PrimeToastAction(label: actionLabel, onPressed: onAction)
        : null,
  );
}

PrimeToastVariant _inferVariant(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('ошиб') ||
      lower.contains('не удалось') ||
      lower.contains('невер') ||
      lower.contains('отклон') ||
      lower.contains('запрещ') ||
      lower.contains('failed')) {
    return PrimeToastVariant.error;
  }
  if (lower.contains('нет сети') ||
      lower.contains('скоро') ||
      lower.contains('подожд') ||
      lower.contains('ждём')) {
    return PrimeToastVariant.warning;
  }
  if (lower.contains('сохран') ||
      lower.contains('отправ') ||
      lower.contains('обновл') ||
      lower.contains('принят') ||
      lower.contains('расширен') ||
      lower.contains('остановлен') ||
      lower.contains('изменён') ||
      lower.contains('изменен') ||
      lower.contains('куплен') ||
      lower.contains('активирован') ||
      lower.contains('готов') ||
      lower.contains('можно общаться') ||
      lower.contains('скопирован') ||
      lower.contains('удален') ||
      lower.contains('удалён') ||
      lower.contains('заявка отправлена') ||
      lower.contains('напоминание отправлено')) {
    return PrimeToastVariant.success;
  }
  return PrimeToastVariant.info;
}

void showSuccessSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message, variant: PrimeToastVariant.success);

void showErrorSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message, variant: PrimeToastVariant.error);

void showWarningSnackBar(BuildContext context, String message) =>
    showAppSnackBar(context, message, variant: PrimeToastVariant.warning);

/// Shows loading toast if [future] exceeds [threshold].
Future<T> showSlowActionNotice<T>(
  BuildContext context,
  Future<T> future, {
  Duration threshold = const Duration(milliseconds: 2500),
  String message = 'Долго грузится, ждём сервер',
}) =>
    withSlowActionNotice(context, future, threshold: threshold, message: message);

/// Maps API / failure strings to error toasts.
void showErrorFrom(BuildContext context, Object error) {
  showAppSnackBar(
    context,
    error is String ? error : error.toString(),
    variant: PrimeToastVariant.error,
  );
}
