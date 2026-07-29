import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/widgets/async_error_view.dart';

void main() {
  testWidgets('повтор запроса вызывается из состояния ошибки', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AsyncErrorView(
          message: 'Нет соединения',
          onRetry: () async => retries++,
        ),
      ),
    );

    expect(find.text('Нет соединения'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(retries, 1);
  });
}
