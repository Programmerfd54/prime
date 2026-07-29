/// Live password strength detector for registration / reset / settings.
enum PasswordStrength { veryWeak, weak, medium, strong }

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.strength,
    required this.score,
    this.hint,
  });

  final PasswordStrength strength;
  final int score;
  final String? hint;

  String get label => switch (strength) {
        PasswordStrength.veryWeak => 'Очень слабый',
        PasswordStrength.weak => 'Слабый',
        PasswordStrength.medium => 'Средний',
        PasswordStrength.strong => 'Сильный',
      };

  /// Segment index 0..3 for the 4-bar indicator.
  int get filledBars => switch (strength) {
        PasswordStrength.veryWeak => 1,
        PasswordStrength.weak => 2,
        PasswordStrength.medium => 3,
        PasswordStrength.strong => 4,
      };

  bool get allowsContinue => strength != PasswordStrength.veryWeak;
}

abstract final class PasswordStrengthAnalyzer {
  static final _letter = RegExp(r'[A-Za-zА-Яа-яЁё]');
  static final _upper = RegExp(r'[A-ZА-ЯЁ]');
  static final _lower = RegExp(r'[a-zа-яё]');
  static final _digit = RegExp(r'\d');
  static final _symbol = RegExp(r'[^A-Za-zА-Яа-яЁё0-9\s]');
  static final _space = RegExp(r'\s');

  /// Hard gate used by validators — anything failing this is [veryWeak].
  static String? hardRequirementHint(String password) {
    if (password.isEmpty) return 'Введите пароль';
    if (_space.hasMatch(password)) return 'Уберите пробелы';
    if (password.length < 8) return 'Добавьте символы — минимум 8';
    if (!_letter.hasMatch(password)) return 'Добавьте букву';
    if (!_digit.hasMatch(password)) return 'Добавьте цифру';
    return null;
  }

  static PasswordStrengthResult analyze(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        strength: PasswordStrength.veryWeak,
        score: 0,
        hint: 'Введите пароль',
      );
    }

    final hard = hardRequirementHint(password);
    if (hard != null) {
      return PasswordStrengthResult(
        strength: PasswordStrength.veryWeak,
        score: 0,
        hint: hard,
      );
    }

    var score = 2; // base after hard requirements
    if (password.length >= 12) score += 1;
    if (_upper.hasMatch(password) && _lower.hasMatch(password)) score += 1;
    if (_symbol.hasMatch(password)) score += 1;
    if (!_hasRepeatRun(password) && !_hasSequentialRun(password)) score += 1;

    final strength = switch (score) {
      <= 2 => PasswordStrength.weak,
      3 || 4 => PasswordStrength.medium,
      _ => PasswordStrength.strong,
    };

    String? hint;
    if (!_upper.hasMatch(password) || !_lower.hasMatch(password)) {
      hint = 'Добавьте верхний и нижний регистр';
    } else if (!_symbol.hasMatch(password)) {
      hint = 'Добавьте символ (!@#) — будет надёжнее';
    } else if (password.length < 12) {
      hint = 'Сделайте пароль длиннее — от 12 символов';
    } else if (strength != PasswordStrength.strong) {
      hint = 'Избегайте повторов и простых последовательностей';
    }

    return PasswordStrengthResult(
      strength: strength,
      score: score,
      hint: strength == PasswordStrength.strong ? null : hint,
    );
  }

  /// Shared FormField validator for register / reset / settings.
  static String? validateForRegister(String? value) {
    final password = value ?? '';
    final result = analyze(password);
    if (!result.allowsContinue) {
      return result.hint ?? 'Пароль слишком слабый';
    }
    return null;
  }

  static String? validateForLogin(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Введите пароль';
    return null;
  }

  static bool _hasRepeatRun(String password) {
    if (password.length < 3) return false;
    for (var i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  static bool _hasSequentialRun(String password) {
    const seqs = ['0123456789', 'abcdefghijklmnopqrstuvwxyz', 'qwertyuiop'];
    final lower = password.toLowerCase();
    for (final seq in seqs) {
      for (var i = 0; i <= seq.length - 3; i++) {
        final chunk = seq.substring(i, i + 3);
        if (lower.contains(chunk)) return true;
      }
    }
    return false;
  }
}
