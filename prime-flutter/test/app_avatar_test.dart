import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/ui/components/profile/app_avatar.dart';

void main() {
  testWidgets('AppAvatar shows initial when photoUrl is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppAvatar(photoUrl: null, name: 'Daniel'),
        ),
      ),
    );

    expect(find.text('D'), findsOneWidget);
    expect(find.byKey(const ValueKey('empty')), findsOneWidget);
  });

  testWidgets('AppAvatar uses @nickname initial', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppAvatar(photoUrl: null, name: '@prime_user'),
        ),
      ),
    );

    expect(find.text('P'), findsOneWidget);
  });

  test('AppAvatar.evictCache is safe for null and invalid urls', () async {
    await AppAvatar.evictCache(null);
    await AppAvatar.evictCache('');
  });
}
