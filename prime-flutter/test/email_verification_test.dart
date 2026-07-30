import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/data/api_client.dart';
import 'package:prime/models/email_verification.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/components/app_code_field.dart';

void main() {
  group('EmailVerificationTicket', () {
    test('читает ответ register', () {
      final ticket = EmailVerificationTicket.fromJson({
        'status': 'verification_required',
        'email': 'Newbie@Example.com',
        'expires_at': '2026-07-29T20:15:00Z',
        'resend_available_in_seconds': 60,
      });

      expect(ticket.email, 'newbie@example.com');
      expect(ticket.resendAvailableInSeconds, 60);
      expect(ticket.expiresAt, isNotNull);
      expect(ticket.devCode, isNull);
    });

    test('подхватывает код с dev-бэкенда', () {
      final ticket = EmailVerificationTicket.fromJson({
        'email': 'dev@example.com',
        'verification_code': '123456',
      });

      expect(ticket.devCode, '123456');
      expect(ticket.resendAvailableInSeconds, 0);
    });
  });

  group('UserModel', () {
    Map<String, dynamic> baseJson() => {
          'id': 'u1',
          'nickname': 'tester',
          'email': 'tester@example.com',
          'name': 'Тестер',
          'about': '',
          'created_at': '2026-07-29T20:00:00Z',
        };

    test('читает флаг email_verified', () {
      final json = baseJson()..['email_verified'] = false;
      expect(UserModel.fromJson(json).emailVerified, isFalse);
    });

    test('считает почту подтверждённой, если старый backend не вернул флаг', () {
      expect(UserModel.fromJson(baseJson()).emailVerified, isTrue);
    });
  });

  group('ApiClient', () {
    test('verify-email отправляет нормализованные email и код', () async {
      final api = ApiClient();
      final adapter = _CapturingAdapter('{"access_token":"jwt","token_type":"bearer"}');
      api.dio.httpClientAdapter = adapter;

      final result = await api.verifyEmail(
        email: '  Newbie@Example.com ',
        code: ' 123456 ',
      );

      expect(adapter.path, '/auth/verify-email');
      expect(adapter.body, {'email': 'newbie@example.com', 'code': '123456'});
      expect(result['access_token'], 'jwt');
      api.dispose();
    });

    test('resend-verification обращается к своему эндпоинту', () async {
      final api = ApiClient();
      final adapter = _CapturingAdapter('{"status":"ok"}');
      api.dio.httpClientAdapter = adapter;

      await api.resendVerification('Newbie@Example.com');

      expect(adapter.path, '/auth/resend-verification');
      expect(adapter.body, {'email': 'newbie@example.com'});
      api.dispose();
    });
  });

  group('AppCodeField', () {
    testWidgets('показывает введённые цифры по ячейкам', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCodeField(controller: controller, autofocus: false),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();

      for (final digit in ['1', '2', '3', '4']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('сообщает о полном коде и отбрасывает лишние символы',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCodeField(
              controller: controller,
              autofocus: false,
              onCompleted: (value) => completed = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '12a34b56789');
      await tester.pump();

      expect(controller.text, '123456');
      expect(completed, '123456');
    });
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.responseBody);

  final String responseBody;
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    final data = options.data;
    body = data is Map<String, dynamic>
        ? data
        : jsonDecode(data.toString()) as Map<String, dynamic>;
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
