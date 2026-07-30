import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/theme/prime_theme.dart';
import 'package:prime/l10n/copy.dart';
import 'package:prime/ui/components/editorial/app_group_editorial.dart';

void main() {
  testWidgets('AppGroupRulesPanel shows V6 team pact copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrimeTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: AppGroupRulesPanel(),
          ),
        ),
      ),
    );

    expect(find.text(AppCopy.teamPactTitle), findsOneWidget);
    expect(find.textContaining('без давления'), findsOneWidget);
    expect(find.textContaining('слабее тебя'), findsNothing);
  });
}
