import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forbidden font families are not referenced in lib/', () {
    const forbidden = [
      'Poppins',
      'PlayfairDisplay',
      'Playfair Display',
      'Unbounded',
      'GoogleFonts',
    ];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from prime-flutter root');

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final token in forbidden) {
        if (text.contains(token)) {
          violations.add('${entity.path}: $token');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Remove forbidden fonts:\n${violations.join('\n')}',
    );
  });

  test('ThemeData uses Manrope as global fontFamily', () {
    // Sanity check via typography token — full theme covered in smoke test.
    expect(
      RegExp(r"family\s*=\s*'Manrope'").hasMatch(
        File('lib/design/typography.dart').readAsStringSync(),
      ),
      isTrue,
    );
  });
}
