import 'package:prime/core/habits/habit_favorites.dart';
import 'package:prime/core/onboarding/onboarding_preferences.dart';
import 'package:prime/core/sync/device_timezone.dart';
import 'package:prime/data/api_client.dart';

/// Merges onboarding prefs + habit favorites between device and backend.
class UserPersonalizationSync {
  const UserPersonalizationSync._();

  /// After auth: pull remote, push local gaps, unify favorites.
  static Future<void> syncAfterAuth(ApiClient api) async {
    final localPrefs = await OnboardingPreferences.load();
    final localFavs = await HabitFavorites.load();

    Map<String, dynamic> remotePrefsRaw;
    List<String> remoteFavs;
    try {
      remotePrefsRaw = await api.getPreferences();
      remoteFavs = (await api.listFavoriteSkills()).toList();
    } catch (_) {
      return;
    }

    final remotePrefs = OnboardingPreferences.fromJson(remotePrefsRaw);
    final mergedPrefs = _mergePreferences(localPrefs, remotePrefs);
    await OnboardingPreferences.save(mergedPrefs);

    final remoteFavSet = remoteFavs.toSet();
    final mergedFavs = {...localFavs, ...remoteFavSet};
    await HabitFavorites.replaceAll(mergedFavs);

    try {
      if (_prefsDiffer(mergedPrefs, remotePrefs)) {
        await api.updatePreferences(mergedPrefs.toJson());
      }
      final localTz = await DeviceTimezone.localIana();
      if (localTz != null) {
        await api.updateMe({'timezone': localTz});
      }
      for (final skillId in mergedFavs.difference(remoteFavSet)) {
        await api.addFavoriteSkill(skillId);
      }
      for (final skillId in remoteFavSet.difference(mergedFavs)) {
        await api.removeFavoriteSkill(skillId);
      }
    } catch (_) {
      // Local cache already updated; server catches up on next toggle.
    }
  }

  static Future<void> pushOnboarding(ApiClient api) async {
    final prefs = await OnboardingPreferences.load();
    if (prefs.goal == null &&
        prefs.selectedSkillId == null &&
        prefs.completedAt == null) {
      return;
    }
    try {
      await api.updatePreferences(prefs.toJson());
    } catch (_) {}
  }

  static Future<void> pushFavoriteToggle(
    ApiClient api,
    String skillId,
    bool added,
  ) async {
    try {
      if (added) {
        await api.addFavoriteSkill(skillId);
      } else {
        await api.removeFavoriteSkill(skillId);
      }
    } catch (_) {}
  }

  static OnboardingPreferences _mergePreferences(
    OnboardingPreferences local,
    OnboardingPreferences remote,
  ) {
    if (_isEmpty(remote) && !_isEmpty(local)) return local;
    if (_isEmpty(local) && !_isEmpty(remote)) return remote;

    final localAt = local.completedAt;
    final remoteAt = remote.completedAt;
    if (localAt != null && remoteAt != null) {
      return localAt.isAfter(remoteAt) ? local : remote;
    }
    if (localAt != null) return local;
    if (remoteAt != null) return remote;
    if (local.selectedSkillId != null || local.goal != null) return local;
    return remote;
  }

  static bool _prefsDiffer(
    OnboardingPreferences a,
    OnboardingPreferences b,
  ) =>
      a.goal?.name != b.goal?.name ||
      a.selectedSkillId != b.selectedSkillId ||
      a.habitQuitCount != b.habitQuitCount ||
      a.habitAttemptCount != b.habitAttemptCount ||
      a.completedAt?.toIso8601String() != b.completedAt?.toIso8601String() ||
      !_sameGoals(a.goals, b.goals);

  static bool _sameGoals(List<OnboardingGoal> a, List<OnboardingGoal> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _isEmpty(OnboardingPreferences prefs) =>
      prefs.goal == null &&
      prefs.goals.isEmpty &&
      prefs.selectedSkillId == null &&
      prefs.completedAt == null;
}
