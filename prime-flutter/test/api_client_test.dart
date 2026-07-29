import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/constants.dart';
import 'package:prime/data/api_client.dart';

void main() {
  test('API использует порт 8080 по умолчанию', () {
    expect(Uri.parse(apiBaseUrl).port, 8080);
  });

  test('API показывает безопасный detail из ответа backend', () {
    final request = RequestOptions(path: '/test');
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 422,
        data: {'detail': 'Некорректные данные'},
      ),
    );

    expect(ApiClient.errorMessage(error), 'Некорректные данные');
  });

  test('API скрывает технический detail', () {
    final request = RequestOptions(path: '/test');
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 500,
        data: {'detail': 'Exception: Traceback'},
      ),
    );

    expect(ApiClient.errorMessage(error), contains('технической ошибки'));
  });

  test('API распознаёт истёкшую авторизацию', () {
    final request = RequestOptions(path: '/test');
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
    );

    expect(ApiClient.isUnauthorized(error), isTrue);
  });

  test('при старом backend используется встроенный список областей', () async {
    final api = ApiClient();
    api.dio.httpClientAdapter = _NotFoundAdapter();

    final regions = await api.listRegions();
    final byCode = {
      for (final region in regions)
        region['code'] as String: region['name'] as String,
    };

    expect(byCode['77'], 'Москва');
    expect(byCode['50'], 'Московская область');
    api.dispose();
  });
}

class _NotFoundAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"detail":"Not Found"}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
