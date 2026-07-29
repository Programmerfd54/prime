import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/ui/states/app_empty_state.dart';
import 'package:prime/ui/states/app_error_state.dart';

void main() {
  testWidgets('AppEmptyState shows CTA and triggers action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'Выберите привычку',
            subtitle: 'Чтобы начать поиск команды',
            actionLabel: AppCopy.findTeam,
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Выберите привычку'), findsOneWidget);
    await tester.tap(find.text(AppCopy.findTeam));
    expect(tapped, isTrue);
  });

  testWidgets('AppErrorState retry works', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppErrorState(
            message: 'Не удалось загрузить',
            onRetry: () async {
              retried = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text(AppCopy.retry));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('AppErrorState shows correlation code and copy action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorState(
            message: 'Не удалось загрузить',
            correlationId: 'corr-42',
          ),
        ),
      ),
    );

    expect(find.textContaining('corr-42'), findsOneWidget);
    expect(find.text(AppCopy.copyCode), findsOneWidget);
  });
}
