import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/security/password_strength.dart';

void main() {
  test('empty and short passwords are veryWeak', () {
    expect(
      PasswordStrengthAnalyzer.analyze('').strength,
      PasswordStrength.veryWeak,
    );
    expect(
      PasswordStrengthAnalyzer.analyze('abc12').strength,
      PasswordStrength.veryWeak,
    );
    expect(
      PasswordStrengthAnalyzer.validateForRegister('short1'),
      isNotNull,
    );
  });

  test('meets hard gate with letter+digit length 8 is at least weak', () {
    final result = PasswordStrengthAnalyzer.analyze('password1');
    expect(result.allowsContinue, isTrue);
    expect(result.strength, isNot(PasswordStrength.veryWeak));
  });

  test('mixed case + symbol + length upgrades strength', () {
    final weakish = PasswordStrengthAnalyzer.analyze('password1');
    final strong = PasswordStrengthAnalyzer.analyze('Passw0rd!Xy');
    expect(strong.filledBars, greaterThan(weakish.filledBars));
    expect(strong.strength, PasswordStrength.strong);
    expect(PasswordStrengthAnalyzer.validateForRegister('Passw0rd!Xy'), isNull);
  });

  test('login validator only checks emptiness', () {
    expect(PasswordStrengthAnalyzer.validateForLogin(''), 'Введите пароль');
    expect(PasswordStrengthAnalyzer.validateForLogin('x'), isNull);
  });

  test('spaces rejected', () {
    expect(
      PasswordStrengthAnalyzer.analyze('pass word1').hint,
      contains('пробел'),
    );
  });
}
