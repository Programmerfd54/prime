import 'package:dio/dio.dart';

import '../../l10n/copy.dart';
import 'app_failure.dart';

/// Maps transport/backend errors to user-friendly Russian [AppFailure]s.
///
/// Explicit HTTP coverage: 400, 401, 403, 404, 409, 413, 422, 429, 500,
/// 502/503/504, plus [DioExceptionType] timeout and connectionError
/// ("offline"). Raw backend payloads/tracebacks are never shown to users —
/// see [_preferSafeDetail].
abstract final class FailureMapper {
  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is DioException) return fromDio(error);
    return UnknownFailure(debugDetail: error.toString());
  }

  static AppFailure fromDio(DioException error) {
    final status = error.response?.statusCode;
    final correlationId = _correlationId(error.response?.headers);
    final debugDetail = _extractDetail(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(
          correlationId: correlationId,
          debugDetail: debugDetail,
        );
      case DioExceptionType.connectionError:
        return NetworkFailure(
          correlationId: correlationId,
          debugDetail: debugDetail,
        );
      case DioExceptionType.badResponse:
        return _fromStatus(
          status,
          correlationId: correlationId,
          debugDetail: debugDetail,
          retryAfter: _retryAfter(error.response?.headers),
        );
      case DioExceptionType.cancel:
        return const UnknownFailure(message: 'Запрос был отменён.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.error != null && status == null) {
          return NetworkFailure(
            correlationId: correlationId,
            debugDetail: debugDetail ?? error.error.toString(),
          );
        }
        return _fromStatus(
          status,
          correlationId: correlationId,
          debugDetail: debugDetail,
        );
    }
  }

  static AppFailure _fromStatus(
    int? status, {
    String? correlationId,
    String? debugDetail,
    int? retryAfter,
  }) {
    return switch (status) {
      400 || 422 => ValidationFailure(
          message: _preferSafeDetail(debugDetail) ?? AppCopy.validation,
          statusCode: status,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      401 => UnauthorizedFailure(
          // Login returns a human RU detail; mid-session JWT expiry often has none.
          message: _preferSafeDetail(debugDetail) ?? AppCopy.unauthorized,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      403 => ForbiddenFailure(
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      404 => NotFoundFailure(
          message: _preferSafeDetail(debugDetail) ?? AppCopy.notFound,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      409 => ConflictFailure(
          message: _preferSafeDetail(debugDetail) ?? AppCopy.conflict,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      413 => PayloadTooLargeFailure(
          message: _preferSafeDetail(debugDetail) ?? AppCopy.payloadTooLarge,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      429 => RateLimitFailure(
          message: retryAfter != null && retryAfter > 0
              ? AppCopy.rateLimitWithRetry(retryAfter)
              : AppCopy.rateLimit,
          correlationId: correlationId,
          debugDetail: debugDetail,
          retryAfterSeconds: retryAfter,
        ),
      502 || 503 || 504 => ServiceUnavailableFailure(
          statusCode: status,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      final code when code != null && code >= 500 => ServerFailure(
          statusCode: code,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
      _ => UnknownFailure(
          statusCode: status,
          correlationId: correlationId,
          debugDetail: debugDetail,
        ),
    };
  }

  static final _stockHttpDetail = RegExp(
    r'^(not found|method not allowed|internal server error|bad request|'
    r'unauthorized|forbidden|validation error|unprocessable entity)$',
    caseSensitive: false,
  );

  /// Use backend detail only when it looks like a short human RU message.
  static String? _preferSafeDetail(String? detail) {
    if (detail == null) return null;
    final trimmed = detail.trim();
    if (trimmed.isEmpty || trimmed.length > 180) return null;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return null;
    if (trimmed.contains('Traceback') || trimmed.contains('Exception')) {
      return null;
    }
    // Reject garbled/empty backend strings (spaces-only messages).
    if (RegExp(r'^\s+$').hasMatch(trimmed)) return null;
    if (_stockHttpDetail.hasMatch(trimmed)) return null;
    // Product copy is RU — bare English phrases are usually framework noise.
    if (!RegExp(r'[А-Яа-яЁё]').hasMatch(trimmed) && trimmed.length <= 48) {
      return null;
    }
    return trimmed;
  }

  static String? _extractDetail(dynamic data) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        final parts = <String>[];
        for (final item in detail) {
          if (item is Map && item['msg'] != null) {
            var msg = item['msg'].toString();
            const pydanticPrefix = 'Value error, ';
            if (msg.startsWith(pydanticPrefix)) {
              msg = msg.substring(pydanticPrefix.length);
            }
            parts.add(msg);
          } else {
            parts.add(item.toString());
          }
        }
        return parts.join('; ');
      }
      return detail.toString();
    }
    return null;
  }

  static String? _correlationId(Headers? headers) {
    if (headers == null) return null;
    return headers.value('x-request-id') ??
        headers.value('x-correlation-id') ??
        headers.value('x-amzn-requestid');
  }

  static int? _retryAfter(Headers? headers) {
    final raw = headers?.value('retry-after');
    if (raw == null) return null;
    return int.tryParse(raw);
  }
}
