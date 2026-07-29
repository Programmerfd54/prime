import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/config/theme.dart';
import 'package:prime/ui/components/prime_text_field.dart';

void main() {
  testWidgets('PrimeTextField removes focus listener on dispose', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PrimeTextField(
            controller: controller,
            label: 'Email',
            focusNode: focusNode,
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    focusNode.requestFocus();
    await tester.pump();
    expect(tester.takeException(), isNull);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('PrimeTextField validates prefilled controller text', (tester) async {
    final controller = TextEditingController(text: 'daniel@example.com');
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PrimeTextField(
              controller: controller,
              label: 'Email',
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Введите email';
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(formKey.currentState!.validate(), isTrue);
    expect(find.text('Введите email'), findsNothing);

    controller.dispose();
  });

  testWidgets('PrimeTextField syncs programmatic controller updates', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PrimeTextField(
              controller: controller,
              label: 'Имя',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите имя' : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Укажите имя'), findsOneWidget);

    controller.text = 'Daniel';
    await tester.pump();

    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Укажите имя'), findsNothing);

    controller.dispose();
  });
}
