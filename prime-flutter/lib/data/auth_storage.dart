import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Защищённое хранение токена.
///
/// SharedPreferences используется только для несекретного флага онбординга
/// и однократной миграции данных из старых версий приложения.
class AuthStorage {
  static const _keyToken = 'prime_access_token';
  static const _keyRefreshToken = 'prime_refresh_token';
  static const _keyCachedUser = 'prime_cached_user';
  static const _keyOnboarding = 'prime_onboarding_done';
  static const _keyDeveloperMode = 'prime_developer_mode';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  const AuthStorage();

  Future<void> saveAuth({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secure.write(key: _keyToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secure.write(key: _keyRefreshToken, value: refreshToken);
    } else {
      await _secure.delete(key: _keyRefreshToken);
    }
    await _removeLegacyAuth();
  }

  Future<String?> _readWithMigration(String key) async {
    final secureValue = await _secure.read(key: key);
    if (secureValue != null) return secureValue;

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue != null) {
      await _secure.write(key: key, value: legacyValue);
      await prefs.remove(key);
    }
    return legacyValue;
  }

  Future<String?> get accessToken => _readWithMigration(_keyToken);

  Future<String?> get refreshToken => _secure.read(key: _keyRefreshToken);

  Future<void> saveCachedUser(UserModel user) async {
    await _secure.write(key: _keyCachedUser, value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> get cachedUser async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _secure.read(key: _keyCachedUser) ??
        prefs.getString(_keyCachedUser);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (prefs.containsKey(_keyCachedUser)) {
        await _secure.write(key: _keyCachedUser, value: raw);
        await prefs.remove(_keyCachedUser);
      }
      return UserModel.fromJson(decoded);
    } catch (_) {
      await _secure.delete(key: _keyCachedUser);
      await prefs.remove(_keyCachedUser);
      return null;
    }
  }

  Future<void> clear() async {
    await _secure.delete(key: _keyToken);
    await _secure.delete(key: _keyRefreshToken);
    await _secure.delete(key: _keyCachedUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeveloperMode);
    await prefs.remove(_keyCachedUser);
    await _removeLegacyAuth();
  }

  Future<void> _removeLegacyAuth() async {
    await _secure.delete(key: 'prime_matrix_user');
    await _secure.delete(key: 'prime_matrix_token');
    await _secure.delete(key: 'prime_matrix_home');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    // Ключи Matrix удаляются при миграции со старых версий.
    await prefs.remove('prime_matrix_user');
    await prefs.remove('prime_matrix_token');
    await prefs.remove('prime_matrix_home');
  }

  Future<bool> get onboardingDone async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarding) == true;
  }

  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, false);
  }

  Future<bool> get developerMode async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeveloperMode) == true;
  }

  Future<void> setDeveloperMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeveloperMode, enabled);
  }
}
