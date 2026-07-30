import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/profile/profile_preferences.dart';
import 'package:prime/models/user.dart';
import 'package:prime/ui/kit/presentation/profile_view_model.dart';

void main() {
  UserModel baseUser() => UserModel(
        id: 'u1',
        nickname: 'testuser',
        email: 'test@example.com',
        name: 'Test',
        about: 'word one two three four five',
        profileCompleted: true,
        primePoints: 0,
        successfulDays: 10,
        canCreateCustomSkills: false,
        isModerator: false,
        createdAt: DateTime(2026, 7, 1),
      );

  test('buildOwnAboutData uses profile preferences for facts', () {
    final data = buildOwnAboutData(
      user: baseUser(),
      preferences: const {
        ProfilePreferences.preferredTimeOfDayKey: 'evening',
        ProfilePreferences.supportStyleKey: 'gentle',
      },
    );

    final timeFact = data.facts.firstWhere((f) => f.label == 'Время');
    final supportFact = data.facts.firstWhere((f) => f.label == 'Поддержка');

    expect(timeFact.value, 'Вечер');
    expect(supportFact.value, 'Мягко');
  });

  test('rhythmSupportReady requires both time and support', () {
    expect(ProfilePreferences.rhythmSupportReady(null), isFalse);
    expect(
      ProfilePreferences.rhythmSupportReady({
        ProfilePreferences.preferredTimeOfDayKey: 'morning',
      }),
      isFalse,
    );
    expect(
      ProfilePreferences.rhythmSupportReady({
        ProfilePreferences.preferredTimeOfDayKey: 'morning',
        ProfilePreferences.supportStyleKey: 'strict',
      }),
      isTrue,
    );
    expect(
      ProfilePreferences.rhythmSupportSummary({
        ProfilePreferences.preferredTimeOfDayKey: 'morning',
        ProfilePreferences.supportStyleKey: 'strict',
      }),
      'Утро · Строго',
    );
  });

  test('UserPublic parses email_verified flag', () {
    final user = UserPublic.fromJson({
      'id': 'u2',
      'nickname': 'friend',
      'name': 'Friend',
      'about': '',
      'email_verified': true,
    });
    expect(user.emailVerified, isTrue);
  });
}
