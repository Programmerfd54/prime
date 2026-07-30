import '../../l10n/copy.dart';

sealed class AppFailure implements Exception {
  const AppFailure({
    required this.message,
    this.statusCode,
    this.correlationId,
    this.debugDetail,
  });

  final String message;
  final int? statusCode;
  final String? correlationId;
  final String? debugDetail;

  String get userMessage {
    final support = AppCopy.supportHint(correlationId);
    return '$message\n$support';
  }

  @override
  String toString() => 'AppFailure($statusCode): $message';
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    super.message = AppCopy.validation,
    super.statusCode,
    super.correlationId,
    super.debugDetail,
  });
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    super.message = AppCopy.unauthorized,
    super.statusCode = 401,
    super.correlationId,
    super.debugDetail,
  });
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    super.message = AppCopy.forbidden,
    super.statusCode = 403,
    super.correlationId,
    super.debugDetail,
  });
}

/// Login succeeded on credentials but the signup was never confirmed.
final class EmailNotVerifiedFailure extends AppFailure {
  const EmailNotVerifiedFailure({
    super.message = AppCopy.emailNotVerified,
    super.statusCode = 403,
    super.correlationId,
    super.debugDetail,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = AppCopy.notFound,
    super.statusCode = 404,
    super.correlationId,
    super.debugDetail,
  });
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure({
    super.message = AppCopy.conflict,
    super.statusCode = 409,
    super.correlationId,
    super.debugDetail,
  });
}

final class PayloadTooLargeFailure extends AppFailure {
  const PayloadTooLargeFailure({
    super.message = AppCopy.payloadTooLarge,
    super.statusCode = 413,
    super.correlationId,
    super.debugDetail,
  });
}

final class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    super.message = AppCopy.rateLimit,
    super.statusCode = 429,
    super.correlationId,
    super.debugDetail,
    this.retryAfterSeconds,
  });

  final int? retryAfterSeconds;
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = AppCopy.server,
    super.statusCode = 500,
    super.correlationId,
    super.debugDetail,
  });
}

final class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure({
    super.message = AppCopy.serviceUnavailable,
    super.statusCode = 503,
    super.correlationId,
    super.debugDetail,
  });
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.message = AppCopy.timeout,
    super.correlationId,
    super.debugDetail,
  });
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = AppCopy.network,
    super.correlationId,
    super.debugDetail,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.message = AppCopy.unknown,
    super.statusCode,
    super.correlationId,
    super.debugDetail,
  });
}
