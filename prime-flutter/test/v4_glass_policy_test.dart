import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards V4 glass policy: cards/sheets use solid kit surfaces; blur only via
/// [PrimeGlassSurface] / [LiquidGlass] for nav, dock, and intentional overlays.
void main() {
  test('lib/ has no legacy GlassContainer or design/glass.dart imports', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceFirst('lib/', '');
      final content = entity.readAsStringSync();
      if (content.contains('GlassContainer')) {
        violations.add('$relative: GlassContainer');
      }
      if (content.contains("design/glass.dart") ||
          content.contains("package:prime/design/glass.dart")) {
        violations.add('$relative: design/glass.dart import');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Legacy glass API must not return to production:\n'
          '${violations.join('\n')}',
    );
  });

  test('allowed glass entry points exist', () {
    expect(File('lib/design/liquid/liquid_glass.dart').existsSync(), isTrue);
    expect(File('lib/design/prime/prime_glass_surface.dart').existsSync(), isTrue);
    expect(File('lib/ui/kit/components/prime_glass_overlay.dart').existsSync(), isTrue);
  });
}
