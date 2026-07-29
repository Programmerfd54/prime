import 'package:flutter_test/flutter_test.dart';
import 'package:prime/l10n/copy.dart';

void main() {
  test('product terms use привычка vocabulary', () {
    expect(AppCopy.habits, 'Привычки');
    expect(AppCopy.habit, 'привычка');
    expect(AppCopy.findTeam, 'Найти команду');
    expect(AppCopy.confirmParticipation, isNotEmpty);
  });
}
