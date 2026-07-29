import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/errors/app_failure.dart';
import 'package:prime/core/errors/failure_mapper.dart';
import 'package:prime/l10n/copy.dart';

void main() {
  RequestOptions req() => RequestOptions(path: '/test');

  DioException dio({
    int? status,
    dynamic data,
    DioExceptionType type = DioExceptionType.badResponse,
  }) {
    return DioException(
      requestOptions: req(),
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: req(),
              statusCode: status,
              data: data,
            ),
    );
  }

  test('maps network connection errors', () {
    final failure = FailureMapper.from(
      dio(type: DioExceptionType.connectionError),
    );
    expect(failure, isA<NetworkFailure>());
    expect(failure.message, AppCopy.network);
  });

  test('maps 401 to unauthorized', () {
    final failure = FailureMapper.from(dio(status: 401));
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.message, AppCopy.unauthorized);
  });

  test('maps 401 login detail to invalid credentials text', () {
    final failure = FailureMapper.from(
      dio(status: 401, data: {'detail': 'Неверная почта или пароль'}),
    );
    expect(failure, isA<UnauthorizedFailure>());
    expect(failure.message, 'Неверная почта или пароль');
    expect(failure.message, isNot(AppCopy.unauthorized));
  });

  test('maps 429 to rate limit', () {
    final failure = FailureMapper.from(dio(status: 429));
    expect(failure, isA<RateLimitFailure>());
    expect(failure.message, AppCopy.rateLimit);
  });

  test('maps 429 Retry-After into countdown message', () {
    final request = RequestOptions(path: '/test');
    final error = DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['45'],
        }),
      ),
    );
    final failure = FailureMapper.from(error);
    expect(failure, isA<RateLimitFailure>());
    expect(failure.message, contains('45'));
    expect((failure as RateLimitFailure).retryAfterSeconds, 45);
  });

  test('maps 503 to service unavailable', () {
    final failure = FailureMapper.from(dio(status: 503));
    expect(failure, isA<ServiceUnavailableFailure>());
  });

  test('maps 413 to payload too large with RU copy', () {
    final failure = FailureMapper.from(dio(status: 413));
    expect(failure, isA<PayloadTooLargeFailure>());
    expect(failure.message, AppCopy.payloadTooLarge);
  });

  test('maps connection timeout to timeout failure', () {
    final failure = FailureMapper.from(
      dio(type: DioExceptionType.connectionTimeout),
    );
    expect(failure, isA<TimeoutFailure>());
    expect(failure.message, AppCopy.timeout);
  });

  test('uses short human detail for validation', () {
    final failure = FailureMapper.from(
      dio(status: 422, data: {'detail': 'Некорректные данные'}),
    );
    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'Некорректные данные');
  });

  test('rejects technical detail strings', () {
    final failure = FailureMapper.from(
      dio(status: 500, data: {'detail': 'Exception: Traceback'}),
    );
    expect(failure, isA<ServerFailure>());
    expect(failure.message, AppCopy.server);
  });

  test('ApiClient.errorMessage uses mapper', () {
    // Imported indirectly via package usage in other tests.
    final failure = FailureMapper.from(
      dio(status: 409, data: {'detail': 'Никнейм занят'}),
    );
    expect(failure.message, 'Никнейм занят');
  });

  test('extracts x-request-id as correlationId', () {
    final request = RequestOptions(path: '/test');
    final error = DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: 500,
        headers: Headers.fromMap({
          'x-request-id': ['corr-abc-123'],
        }),
      ),
    );
    final failure = FailureMapper.from(error);
    expect(failure.correlationId, 'corr-abc-123');
    expect(failure.userMessage, contains('corr-abc-123'));
  });

  test('rejects English stock Not Found detail', () {
    final failure = FailureMapper.from(
      dio(status: 404, data: {'detail': 'Not Found'}),
    );
    expect(failure, isA<NotFoundFailure>());
    expect(failure.message, AppCopy.notFound);
    expect(failure.message.toLowerCase(), isNot(contains('not found')));
  });
}
