import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/models/notification.dart';
import 'package:prime/ui/kit/presentation/gate_notifications_presentation.dart';

void main() {
  test('formatNotificationTime shows time for today', () {
    final now = DateTime.now();
    final label = formatNotificationTime(now);
    expect(label, matches(RegExp(r'^\d{2}:\d{2}$')));
  });

  testWidgets('GateNotificationCenterSheet shows unread badge and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: Scaffold(
          body: GateNotificationCenterSheet(
            unreadCount: 2,
            items: [
              PrimeNotification(
                id: '1',
                type: PrimeNotificationType.match,
                title: 'Команда собрана',
                body: 'Подтвердите участие',
                read: false,
                createdAt: DateTime.now(),
                payload: const {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Команда собрана'), findsOneWidget);
  });
}
