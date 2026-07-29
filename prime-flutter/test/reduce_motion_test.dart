import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/design/motion.dart';
import 'package:prime/design/tokens.dart';
import 'package:prime/ui/components/app_skeleton.dart';

void main() {
  testWidgets('AppMotion returns zero duration when animations disabled',
      (tester) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolved = AppMotion.duration(context, AppDurations.slow);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, AppDurations.zero);
  });

  testWidgets('AppSkeleton stays static when animations disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: AppSkeleton(width: 120, height: 16)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // No animation ticks should be required.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
