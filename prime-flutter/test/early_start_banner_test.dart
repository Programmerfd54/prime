import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/models/group.dart';
import 'package:prime/ui/components/groups/app_early_start_banner.dart';

import 'prime_test_harness.dart';

void main() {
  testWidgets('early-start banner counts down and disables expired proposal',
      (tester) async {
    var confirmations = 0;
    final status = WaitingRoomStatus(
      inQueue: true,
      peopleWaiting: 3,
      needed: 6,
      earlyStartPending: true,
      earlyStartConfirmedCount: 1,
      earlyStartNeededConfirmations: 3,
      earlyStartRequestId: 'request-1',
      earlyStartProposerName: 'Анна',
      earlyStartSecondsRemaining: 3,
    );

    await tester.pumpWidget(
      primeTestApp(
        size: const Size(390, 700),
        home: Scaffold(
          body: AppEarlyStartBanner(
            status: status,
            onConfirm: () => confirmations++,
            onKeepWaiting: () {},
          ),
        ),
      ),
    );

    expect(find.text('Анна предлагает старт втроём'), findsOneWidget);
    expect(find.textContaining('на решение'), findsOneWidget);

    await tester.tap(find.text('Подтвердить старт втроём'));
    expect(confirmations, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Время истекло'), findsOneWidget);

    await tester.tap(find.text('Подтвердить старт втроём'));
    expect(confirmations, 1);
  });
}
