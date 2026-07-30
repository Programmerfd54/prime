import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// V5 glass policy — no white specular leaks in liquid glass layers.
void main() {
  test('liquid_glass.dart has no white fill alpha above 0.15 in glass layers', () {
    final file = File('lib/design/liquid/liquid_glass.dart');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();

    final whiteFillPattern = RegExp(
      r'Colors\.white\.withValues\(alpha:\s*([0-9.]+)\)',
    );
    final violations = <String>[];
    for (final match in whiteFillPattern.allMatches(content)) {
      final alpha = double.tryParse(match.group(1) ?? '') ?? 1.0;
      if (alpha > 0.15) {
        violations.add('Colors.white alpha $alpha at offset ${match.start}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'V5 forbids white glass leaks:\n${violations.join('\n')}',
    );
  });

  test('V5 glass entry points exist', () {
    expect(File('lib/design/prime/prime_glass_v5.dart').existsSync(), isTrue);
    expect(File('lib/design/prime/prime_toast_overlay.dart').existsSync(), isTrue);
    expect(File('lib/ui/kit/components/prime_action_menu.dart').existsSync(), isTrue);
    expect(File('lib/ui/components/chat/app_chat_shell.dart').existsSync(), isTrue);
    expect(File('../docs/V5_UI_UX_MEGA_PROMPT.md').existsSync(), isTrue);
  });

  test('prime_bottom_navigation selection pill uses liquid glass white fill', () {
    final nav = File('lib/ui/kit/components/prime_bottom_navigation.dart');
    final v5 = File('lib/design/prime/prime_glass_v5.dart');
    expect(nav.readAsStringSync().contains('PrimeGlassV5.dockSelectionFill'), isTrue);
    expect(v5.readAsStringSync().contains('Colors.white.withValues'), isTrue);
    expect(v5.readAsStringSync().contains('0.88'), isTrue);
  });
}
