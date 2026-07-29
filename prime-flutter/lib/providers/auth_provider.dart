import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/media/media_urls.dart';
import '../core/errors/failure_mapper.dart';
import '../core/sync/user_personalization_sync.dart';
import '../data/api_client.dart';
import '../data/auth_storage.dart';
import '../models/user.dart';

void _log(String msg) {
  dev.log(msg, name: 'auth');
}

/// Глобальное состояние авторизации.
class AuthProvider extends ChangeNotifier {
  final ApiClient api;
  final AuthStorage _storage = const AuthStorage();
  bool _disposed = false;

  AuthProvider(this.api) {
    api.onUnauthorized = () {
      // Fire-and-forget; avoid awaiting inside Dio interceptor.
      handleUnauthorized();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    api.onUnauthorized = null;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  bool _sessionExpiredNotice = false;
  bool get sessionExpiredNotice => _sessionExpiredNotice;

  void clearSessionExpiredNotice() {
    _sessionExpiredNotice = false;
  }

  Future<void> handleUnauthorized() async {
    if (_disposed || _user == null) return;
    _log('Unauthorized mid-session — clearing auth');
    await _storage.clear();
    await api.clearResponseCache();
    api.setAuthToken(null);
    if (_disposed) return;
    _user = null;
    _offlineMode = false;
    _sessionExpiredNotice = true;
    _safeNotify();
  }

  UserModel? _user;
  UserModel? get user => _user;

  bool _loading = false;
  bool get loading => _loading;

  bool _initializing = true;
  bool get initializing => _initializing;

  bool _onboardingDone = false;
  bool get onboardingDone => _onboardingDone;

  /// Set from the onboarding "already have an account?" link so the
  /// post-onboarding auth screen opens directly in login mode.
  bool _preferLoginOnAuth = false;
  bool get preferLoginOnAuth => _preferLoginOnAuth;

  void requestLoginOnNextAuth() {
    _preferLoginOnAuth = true;
  }

  bool _developerMode = false;
  bool get developerMode => _developerMode;

  String? _initializationError;
  String? get initializationError => _initializationError;

  bool _offlineMode = false;
  bool get offlineMode => _offlineMode;

  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    if (_disposed) return;
    _initializationError = null;
    _offlineMode = false;
    try {
      _onboardingDone = await _storage.onboardingDone;
      _developerMode = await _storage.developerMode;
      // На чистой установке не инициализируем Android Keystore до первого
      // кадра: пользователь ещё не мог иметь сохранённую сессию.
      if (!_onboardingDone) return;
      final token = await _storage.accessToken;
      if (token != null) {
        api.setAuthToken(token);
        try {
          await _setUserFromJson(await api.getMe());
          _log('User loaded from token');
        } catch (e) {
          if (ApiClient.isUnauthorized(e)) rethrow;
          final cachedUser = await _storage.cachedUser;
          if (cachedUser != null) {
            _user = cachedUser;
            _offlineMode = true;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      if (_disposed) return;
      _log('Initialization failed: $e');
      if (ApiClient.isUnauthorized(e)) {
        await _storage.clear();
        api.setAuthToken(null);
      } else {
        _initializationError = FailureMapper.from(e).message;
      }
    } finally {
      if (!_disposed) {
        _initializing = false;
        _safeNotify();
      }
    }
  }

  Future<void> retryInit() async {
    _initializing = true;
    _safeNotify();
    await init();
  }

  Future<void> finishOnboarding() async {
    await _storage.markOnboardingDone();
    _onboardingDone = true;
    _safeNotify();
  }

  /// Clears the onboarding flag so Gate shows OnboardingScreen again.
  Future<void> replayOnboarding() async {
    await _storage.resetOnboarding();
    _onboardingDone = false;
    _safeNotify();
  }

  Future<void> _persistAuth(Map<String, dynamic> tokenJson) async {
    final token = tokenJson['access_token'] as String;
    _log('Saving token...');
    await _storage.saveAuth(accessToken: token);
    _log('Token saved, setting auth header');
    api.setAuthToken(token);
  }

  Future<void> _setUserFromJson(Map<String, dynamic> json) async {
    final user = UserModel.fromJson(json);
    _user = user;
    _offlineMode = false;
    await _storage.saveCachedUser(user);
    await UserPersonalizationSync.syncAfterAuth(api);
  }

  Future<void> register(String email, String password,
      {required String name, required String nickname}) async {
    _loading = true;
    _safeNotify();
    try {
      _log('Registering user...');
      final j = await api.register(
        email,
        password,
        name: name,
        nickname: nickname,
      );
      _log('Register OK, persisting auth...');
      await _persistAuth(j);
      _log('Fetching /users/me...');
      await _setUserFromJson(await api.getMe());
      _log('User loaded');
    } catch (e) {
      _log('Register error: $e');
      rethrow;
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> login(String email, String password,
      {bool developerMode = false}) async {
    _loading = true;
    _safeNotify();
    try {
      final j = await api.login(
        email,
        password,
        developerMode: developerMode,
      );
      await _persistAuth(j);
      _developerMode = developerMode;
      await _storage.setDeveloperMode(developerMode);
      await _setUserFromJson(await api.getMe());
    } catch (e) {
      _log('Login error: $e');
      rethrow;
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> refreshUser() async {
    await _setUserFromJson(await api.getMe());
    _safeNotify();
  }

  Future<void> uploadAvatarBytes({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final previousUrl = _user?.photoUrl;
    await _setUserFromJson(await api.uploadAvatarBytes(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    ));
    await _evictAvatarCache(previousUrl);
    await _evictAvatarCache(_user?.photoUrl);
    _safeNotify();
  }

  Future<void> deleteAvatar() async {
    final previousUrl = _user?.photoUrl;
    await _setUserFromJson(await api.deleteAvatar());
    await _evictAvatarCache(previousUrl);
    _safeNotify();
  }

  Future<void> _evictAvatarCache(String? photoUrl) async {
    final url = absolutePhotoUrl(photoUrl);
    if (url == null) return;
    try {
      await NetworkImage(url).evict();
    } catch (_) {
      // Best-effort cache eviction.
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    await api.clearResponseCache();
    api.setAuthToken(null);
    _user = null;
    _offlineMode = false;
    _developerMode = false;
    _safeNotify();
  }
}
