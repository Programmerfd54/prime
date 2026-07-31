import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/features/moderator_features.dart';
import '../models/social_restriction.dart';
import 'regions.dart';

class ApiClient {
  static const _cachePrefix = 'prime_api_cache_v1:';

  static const inboxCacheTtl = Duration(seconds: 45);
  static const messagesCacheTtl = Duration(seconds: 30);
  static const groupsCacheTtl = Duration(minutes: 5);
  static const friendsCacheTtl = Duration(minutes: 5);
  static const nicknameLookupCacheTtl = Duration(seconds: 45);

  static final _chatOptions = Options(
    connectTimeout: Duration(seconds: 8),
    sendTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 15),
  );

  static final _socialOptions = _chatOptions;

  final Map<String, _MemoryCacheEntry> _memoryCache = {};

  /// Default HTTP timeouts — chat endpoints may use [chatDioOptions].
  static const defaultConnectTimeout = Duration(seconds: 25);
  static const defaultSendTimeout = Duration(seconds: 30);
  static const defaultReceiveTimeout = Duration(seconds: 45);

  late final Dio dio;

  /// Called once when a mid-session 401 is observed (not login/register).
  void Function()? onUnauthorized;
  Future<bool> Function()? onTokenRefresh;
  Future<bool>? _refreshFuture;

  bool _handlingUnauthorized = false;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: '$apiBaseUrl$kApiPrefix',
        connectTimeout: defaultConnectTimeout,
        sendTimeout: defaultSendTimeout,
        receiveTimeout: defaultReceiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          // Never treat public auth endpoints as mid-session expiry.
          final isAuthEndpoint = path.contains('/auth/');
          final skipRefresh =
              error.requestOptions.extra['skipAuthRefresh'] == true;
          if (status == 401 &&
              !isAuthEndpoint &&
              !skipRefresh &&
              onTokenRefresh != null) {
            _refreshFuture ??= onTokenRefresh!().whenComplete(() {
              _refreshFuture = null;
            });
            final refreshed = await _refreshFuture!;
            if (refreshed) {
              try {
                final request = error.requestOptions;
                request.extra['skipAuthRefresh'] = true;
                request.headers['Authorization'] =
                    dio.options.headers['Authorization'];
                final response = await dio.fetch(request);
                handler.resolve(response);
                return;
              } catch (_) {
                // The refreshed request failed; clear the local session below.
              }
            }
          }
          if (status == 401 && !isAuthEndpoint && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            onUnauthorized?.call();
            _handlingUnauthorized = false;
          }
          handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  String? get authToken {
    final auth = dio.options.headers['Authorization']?.toString();
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    return auth.substring(7);
  }

  String get eventsStreamUrl => '$apiBaseUrl$kApiPrefix/events/stream';

  void dispose() => dio.close(force: true);

  static bool isUnauthorized(Object error) {
    if (error is UnauthorizedFailure) return true;
    return error is DioException &&
        (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403);
  }

  static bool isNetworkError(Object error) {
    if (error is NetworkFailure || error is TimeoutFailure) return true;
    if (error is! DioException) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };
  }

  static String errorMessage(Object error) => FailureMapper.from(error).message;

  String _cacheKey(String path, Map<String, dynamic>? queryParameters) {
    final auth = dio.options.headers['Authorization']?.toString() ?? '';
    var userScope = 'anonymous';
    final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
    final parts = token.split('.');
    if (parts.length == 3) {
      try {
        final normalized = base64Url.normalize(parts[1]);
        final claims = jsonDecode(utf8.decode(base64Url.decode(normalized)));
        if (claims is Map && claims['sub'] is String) {
          userScope = 'user:${claims['sub']}';
        }
      } catch (_) {
        // Keep anonymous namespace when a legacy/non-JWT token is present.
      }
    }
    final sortedQuery = <String, dynamic>{};
    final query = queryParameters ?? const <String, dynamic>{};
    for (final key in query.keys.toList()..sort()) {
      sortedQuery[key] = query[key];
    }
    return '$_cachePrefix$userScope:$path:${jsonEncode(sortedQuery)}';
  }

  Future<void> _saveCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  static bool _isSensitiveCachePath(String path) {
    if (path.startsWith('/direct-chats') ||
        path.startsWith('/friends') ||
        path.startsWith('/notifications')) {
      return true;
    }
    return RegExp(r'^/chat/[^/]+/messages$').hasMatch(path);
  }

  Future<void> _persistCache(String key, String path, dynamic data) async {
    if (_isSensitiveCachePath(path)) return;
    await _saveCache(key, data);
  }

  Future<dynamic> _readCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<dynamic> _getCached(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final key = _cacheKey(path, queryParameters);
    try {
      final r = await dio.get(path, queryParameters: queryParameters);
      await _persistCache(key, path, r.data);
      _memoryCache[key] = _MemoryCacheEntry(r.data, DateTime.now());
      return r.data;
    } on DioException catch (error) {
      if (isUnauthorized(error) || !isNetworkError(error)) rethrow;
      if (_isSensitiveCachePath(path)) rethrow;
      final cached = await _readCache(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Stale-while-revalidate: return cached data immediately, refresh in background.
  Future<dynamic> _getCachedSWR(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration ttl = inboxCacheTtl,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(path, queryParameters);

    if (!forceRefresh) {
      final mem = _memoryCache[key];
      if (mem != null) {
        if (DateTime.now().difference(mem.fetchedAt) > ttl) {
          unawaited(_refreshInBackground(key, path, queryParameters));
        }
        return mem.data;
      }
      if (!_isSensitiveCachePath(path)) {
        final disk = await _readCache(key);
        if (disk != null) {
          _memoryCache[key] = _MemoryCacheEntry(
            disk,
            DateTime.now().subtract(ttl),
          );
          unawaited(_refreshInBackground(key, path, queryParameters));
          return disk;
        }
      }
    }

    try {
      return await _fetchAndCache(key, path, queryParameters: queryParameters);
    } on DioException catch (error) {
      if (isUnauthorized(error) || !isNetworkError(error)) rethrow;
      if (_isSensitiveCachePath(path)) rethrow;
      final disk = await _readCache(key);
      if (disk != null) {
        _memoryCache[key] = _MemoryCacheEntry(
          disk,
          DateTime.now().subtract(ttl),
        );
        return disk;
      }
      rethrow;
    }
  }

  Future<void> _refreshInBackground(
    String key,
    String path,
    Map<String, dynamic>? queryParameters,
  ) async {
    try {
      await _fetchAndCache(key, path, queryParameters: queryParameters);
    } catch (_) {
      // Keep serving stale cache.
    }
  }

  Future<dynamic> _fetchAndCache(
    String key,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final r = await dio.get(
      path,
      queryParameters: queryParameters,
      options: _optionsForPath(path),
    );
    await _persistCache(key, path, r.data);
    _memoryCache[key] = _MemoryCacheEntry(r.data, DateTime.now());
    return r.data;
  }

  Options? _optionsForPath(String path) {
    if (path.startsWith('/direct-chats') ||
        path.startsWith('/friends') ||
        path.startsWith('/notifications') ||
        path.startsWith('/users/by-nickname')) {
      return _chatOptions;
    }
    return null;
  }

  /// In-memory cache only — safe to call synchronously on the UI thread.
  dynamic peekMemoryCacheSync(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _memoryCache[_cacheKey(path, queryParameters)]?.data;
  }

  Map<String, dynamic>? peekCalendarAllCacheSync() {
    final raw = peekMemoryCacheSync('/reports/calendar/all');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<dynamic>? peekGroupsCacheSync() {
    final raw = peekMemoryCacheSync('/groups');
    if (raw is List) return List<dynamic>.from(raw);
    return null;
  }

  Map<String, dynamic>? peekGroupsOverviewCacheSync() {
    final raw = peekMemoryCacheSync('/groups/overview');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<Map<String, dynamic>?> peekCalendarAllCache() async {
    final raw = await peekCache('/reports/calendar/all');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<List<dynamic>?> peekGroupsCache() async {
    final raw = await peekCache('/groups');
    if (raw is List) return List<dynamic>.from(raw);
    return null;
  }

  /// In-memory cache only — safe to call synchronously on the UI thread.
  Map<String, dynamic>? peekDirectMessagesCacheSync(String friendId) {
    final path = '/direct-chats/$friendId/messages';
    const query = {'limit': 50};
    final key = _cacheKey(path, query);
    final mem = _memoryCache[key];
    if (mem?.data is Map) {
      return Map<String, dynamic>.from(mem!.data as Map);
    }
    return null;
  }

  /// Read cached response without network (memory → disk).
  Future<dynamic> peekCache(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final key = _cacheKey(path, queryParameters);
    final mem = _memoryCache[key];
    if (mem != null) return mem.data;
    if (_isSensitiveCachePath(path)) return null;
    return _readCache(key);
  }

  Future<void> clearResponseCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ------------------------------------------------------------------ auth
  Future<Map<String, dynamic>> register(
    String email,
    String password, {
    required String name,
    required String nickname,
  }) async {
    final r = await dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
      'nickname': nickname,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<bool> checkNicknameAvailable(
    String nickname, {
    String? forEmail,
  }) async {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    final r = await dio.get(
      '/auth/nickname-available/$normalized',
      queryParameters: forEmail != null && forEmail.isNotEmpty
          ? {'email': forEmail.trim().toLowerCase()}
          : null,
    );
    return (r.data as Map<String, dynamic>)['available'] as bool? ?? false;
  }

  Future<({bool available, bool pendingVerification})> checkEmailAvailable(
    String email,
  ) async {
    final r = await dio.get(
      '/auth/email-available',
      queryParameters: {'email': email.trim().toLowerCase()},
    );
    final data = r.data as Map<String, dynamic>;
    return (
      available: data['available'] as bool? ?? false,
      pendingVerification: data['pending_verification'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool developerMode = false,
  }) async {
    final r = await dio.post('/auth/login', data: {
      'email': email,
      if (password.isNotEmpty) 'password': password,
      'developer_mode': developerMode,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    final r = await dio.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> logoutSession() async {
    await dio.post(
      '/auth/logout',
      options: Options(extra: {'skipAuthRefresh': true}),
    );
  }

  /// Confirms the signup code and returns the first access token.
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final r = await dio.post('/auth/verify-email', data: {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final r = await dio.post('/auth/resend-verification', data: {
      'email': email.trim().toLowerCase(),
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final r = await dio.post('/auth/forgot-password', data: {
      'email': email.trim().toLowerCase(),
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await dio.post('/auth/reset-password', data: {
      'token': token.trim(),
      'new_password': newPassword,
    });
  }

  // ------------------------------------------------------------------ users
  Future<Map<String, dynamic>> getMe() async {
    final r = await dio.get('/users/me');
    return r.data as Map<String, dynamic>;
  }

  Future<void> _invalidatePathCache(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final key = _cacheKey(path, queryParameters);
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  void _invalidateAllNicknameLookups() {
    _memoryCache.removeWhere((key, _) => key.startsWith('nickname_lookup:'));
  }

  Future<void> _invalidateProfileCaches() async {
    await Future.wait([
      _invalidatePathCache('/friends'),
      _invalidatePathCache('/groups'),
      _invalidatePathCache('/direct-chats'),
    ]);
    _invalidateAllNicknameLookups();
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final r = await dio.patch('/users/me', data: data);
    await _invalidateProfileCaches();
    return r.data as Map<String, dynamic>;
  }

  /// Lightweight about save — skips heavy cache invalidation for faster UX.
  Future<Map<String, dynamic>> updateAbout(String about) async {
    final r = await dio.patch('/users/me', data: {'about': about});
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await dio.delete('/users/me');
  }

  Future<SocialRestrictionStatus> fetchMySocialRestriction() async {
    final r = await dio.get('/users/me/restriction');
    return SocialRestrictionStatus.fromJson(
      Map<String, dynamic>.from(r.data as Map),
    );
  }

  Future<Map<String, dynamic>> submitModerationAppeal({
    required String decisionId,
    String explanation = '',
  }) async {
    final r = await dio.post('/moderation/appeals', data: {
      'decision_id': decisionId,
      'explanation': explanation,
    });
    return r.data as Map<String, dynamic>;
  }

  /// Moderator TOTP enrollment — returns otpauth URI for QR display.
  Future<Map<String, dynamic>> enrollModeratorTotp() async {
    if (!ModeratorFeatures.enabled) {
      throw const ForbiddenFailure(
        message: 'Функции модератора отключены',
      );
    }
    final r = await dio.post('/auth/mfa/totp/enroll');
    return r.data as Map<String, dynamic>;
  }

  /// Verify TOTP for enrollment (`confirmEnrollment: true`) or step-up.
  Future<Map<String, dynamic>> verifyModeratorTotp(
    String code, {
    bool confirmEnrollment = false,
  }) async {
    if (!ModeratorFeatures.enabled) {
      throw const ForbiddenFailure(
        message: 'Функции модератора отключены',
      );
    }
    final r = await dio.post('/auth/mfa/totp/verify', data: {
      'code': code.trim(),
      if (confirmEnrollment) 'confirm_enrollment': true,
    });
    return r.data as Map<String, dynamic>;
  }

  /// Single-use backup code step-up for moderators.
  Future<Map<String, dynamic>> verifyModeratorBackupCode(String code) async {
    if (!ModeratorFeatures.enabled) {
      throw const ForbiddenFailure(
        message: 'Функции модератора отключены',
      );
    }
    final r = await dio.post('/auth/mfa/backup-code/verify', data: {
      'code': code.trim(),
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> buyStreakShield() async {
    final r = await dio.post('/users/me/shields/buy');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> useStreakShield() async {
    final r = await dio.post('/users/me/shields/use');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCustomSkill({
    required String name,
    String description = '',
  }) async {
    final r = await dio.post('/skills/custom', data: {
      'name': name,
      'description': description,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyStats() async {
    final r = await dio.get('/users/me/stats');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listPrimeEvents() async {
    final r = await dio.get('/users/me/prime-events');
    return r.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final r = await dio.get('/users/me/preferences');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.patch('/users/me/preferences', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<List<String>> listFavoriteSkills() async {
    final r = await dio.get('/users/me/favorites');
    final raw = r.data as Map<String, dynamic>;
    return (raw['skill_ids'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
  }

  Future<void> addFavoriteSkill(String skillId) async {
    await dio.post('/users/me/favorites/$skillId');
  }

  Future<void> removeFavoriteSkill(String skillId) async {
    await dio.delete('/users/me/favorites/$skillId');
  }

  Future<Map<String, dynamic>> uploadAvatar(String path) async {
    return uploadAvatarBytes(
      bytes: await File(path).readAsBytes(),
      filename: path.split('/').last,
      contentType: _guessImageContentType(path),
    );
  }

  Future<Map<String, dynamic>> uploadAvatarBytes({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final r = await dio.post('/users/me/avatar', data: formData);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    final r = await dio.delete('/users/me/avatar');
    return r.data as Map<String, dynamic>;
  }

  static String _guessImageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await dio.post('/users/me/password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> getEmailPreferences() async {
    final r = await dio.get('/users/me/email-preferences');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmailPreferences({
    required bool marketingEmailsOptIn,
  }) async {
    final r = await dio.patch('/users/me/email-preferences', data: {
      'marketing_emails_opt_in': marketingEmailsOptIn,
    });
    return r.data as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ skills
  Future<List<Map<String, dynamic>>> listRegions() async {
    try {
      final data = await _getCached('/regions') as Map<String, dynamic>;
      final regions = (data['regions'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList();
      return regions.isEmpty ? russianRegions : regions;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 || isNetworkError(error)) {
        return russianRegions;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> listSkills({String? category}) async {
    final data = await _getCached('/skills', queryParameters: {
      if (category != null) 'category': category,
    });
    return data as List<dynamic>;
  }

  // ------------------------------------------------------------------ groups
  Future<Map<String, dynamic>> joinWaitingRoom(String skillId) async {
    final r =
        await dio.post('/groups/waiting-room', data: {'skill_id': skillId});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> waitingRoomStatus({String? skillId}) async {
    final data = await _getCached('/groups/waiting-room', queryParameters: {
      if (skillId != null) 'skill_id': skillId,
    });
    return data as Map<String, dynamic>;
  }

  /// Live (uncached) waiting-room status for polling.
  Future<Map<String, dynamic>> waitingRoomStatusLive({String? skillId}) async {
    final r = await dio.get('/groups/waiting-room', queryParameters: {
      if (skillId != null) 'skill_id': skillId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> invalidateWaitingRoomCache({String? skillId}) async {
    await _invalidatePathCache(
      '/groups/waiting-room',
      queryParameters: {if (skillId != null) 'skill_id': skillId},
    );
    await _invalidatePathCache('/groups/waiting-room');
  }

  Future<void> invalidateGroupsCache() async {
    await _invalidatePathCache('/groups');
    await _invalidatePathCache('/groups/overview');
  }

  Future<void> leaveWaitingRoom({String? skillId}) async => await dio.delete(
        '/groups/waiting-room',
        queryParameters: {if (skillId != null) 'skill_id': skillId},
      );

  Future<Map<String, dynamic>> expandWaitingRoom(String skillId) async {
    final r = await dio.post('/groups/waiting-room/expand', data: {
      'skill_id': skillId,
      'allow': true,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> waitingRoomStats({
    required String skillId,
    required String regionCode,
  }) async {
    final r = await dio.get('/groups/waiting-room/stats', queryParameters: {
      'skill_id': skillId,
      'region_code': regionCode,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWaitingRoomPairInvite(
    String skillId,
  ) async {
    final r = await dio.post('/groups/waiting-room/pair-invite', data: {
      'skill_id': skillId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendWaitingRoomPairInvites({
    required String skillId,
    required List<String> userIds,
  }) async {
    final r = await dio.post('/groups/waiting-room/pair-invite/send', data: {
      'skill_id': skillId,
      'user_ids': userIds,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinWaitingRoomPair(String inviteCode) async {
    final r = await dio.post('/groups/waiting-room/pair-join', data: {
      'invite_code': inviteCode,
    });
    await invalidateWaitingRoomCache();
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmEarlyStart({String? skillId}) async {
    final r = await dio.post('/groups/waiting-room/early-start', data: {
      if (skillId != null && skillId.isNotEmpty) 'skill_id': skillId,
    });
    await invalidateWaitingRoomCache(skillId: skillId);
    await invalidateGroupsCache();
    return r.data as Map<String, dynamic>;
  }

  /// @deprecated Use [confirmEarlyStart]
  Future<Map<String, dynamic>> confirmPairStart({String? skillId}) =>
      confirmEarlyStart(skillId: skillId);

  Future<Map<String, dynamic>> nudgeGroup(String groupId) async {
    final r = await dio.post('/groups/$groupId/nudge');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> supportGroupMember({
    required String groupId,
    required String targetUserId,
    String? message,
  }) async {
    final r = await dio.post('/groups/$groupId/support', data: {
      'target_user_id': targetUserId,
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
    });
    await invalidateGroupsCache();
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> groupsOverview({
    bool forceRefresh = false,
  }) async {
    final data = await _getCachedSWR(
      '/groups/overview',
      ttl: groupsCacheTtl,
      forceRefresh: forceRefresh,
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reconcileMembership() async {
    final r = await dio.post('/groups/membership/reconcile');
    await invalidateGroupsCache();
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> membershipHistory({int limit = 100}) async {
    final r = await dio.get(
      '/groups/membership-history',
      queryParameters: {'limit': limit},
    );
    final data = r.data as Map<String, dynamic>;
    return data['items'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listGroups({bool forceRefresh = false}) async {
    final data = await _getCachedSWR(
      '/groups',
      ttl: groupsCacheTtl,
      forceRefresh: forceRefresh,
    );
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>?> currentGroup() async {
    final r = await dio.get('/groups/current');
    final data = r.data;
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroup(String id) async {
    final r = await dio.get('/groups/$id');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> groupCheckIn(String groupId, String kind) async {
    final r = await dio.post('/groups/$groupId/check-in', data: {'kind': kind});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmParticipation(String groupId) async {
    final r = await dio.post('/groups/$groupId/intro/continue');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changeIntroGroup(String groupId) async {
    final r = await dio.post('/groups/$groupId/intro/change');
    await invalidateGroupsCache();
    await invalidateWaitingRoomCache();
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptRules(String groupId) async {
    final r = await dio.post('/groups/$groupId/rules/accept');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assembleTestTeam(String skillId) async {
    final r = await dio
        .post('/dev/groups/assemble-test-team', data: {'skill_id': skillId});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> vote(String groupId, String choice) async {
    final r = await dio.post('/groups/$groupId/vote', data: {'choice': choice});
    return r.data as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ reports
  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    final r = await dio.post('/reports', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reportUploadMedia(
    String groupId,
    File file,
  ) async {
    final formData = FormData.fromMap({
      'group_id': groupId,
      'file': await MultipartFile.fromFile(file.path),
    });
    final r = await dio.post('/reports/upload', data: formData);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> calendar(String groupId) async {
    final r = await dio
        .get('/reports/calendar', queryParameters: {'group_id': groupId});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> calendarAll({bool forceRefresh = false}) async {
    final data = await _getCachedSWR(
      '/reports/calendar/all',
      ttl: groupsCacheTtl,
      forceRefresh: forceRefresh,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  // ------------------------------------------------------------------ achievements
  Future<List<dynamic>> listAchievements() async {
    return await _getCached('/achievements') as List<dynamic>;
  }

  // ------------------------------------------------------------------ friends
  String _nicknameCacheKey(String nickname) {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    return 'nickname_lookup:$normalized';
  }

  void _invalidateNicknameLookup(String nickname) {
    _memoryCache.remove(_nicknameCacheKey(nickname));
  }

  Future<Map<String, dynamic>> findUserByNickname(
    String nickname, {
    bool forceRefresh = false,
  }) async {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    final cacheKey = _nicknameCacheKey(normalized);
    if (!forceRefresh) {
      final cached = _memoryCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) <=
              nicknameLookupCacheTtl) {
        return Map<String, dynamic>.from(cached.data as Map);
      }
    }
    final r = await dio.get(
      '/users/by-nickname/$normalized',
      options: _socialOptions,
    );
    final data = r.data as Map<String, dynamic>;
    _memoryCache[cacheKey] = _MemoryCacheEntry(data, DateTime.now());
    return data;
  }

  Future<Map<String, dynamic>> discoverUsers({
    String? regionCode,
    String? cursor,
    int limit = 30,
  }) async {
    final r = await dio.get(
      '/users/discover',
      queryParameters: {
        if (regionCode != null && regionCode.isNotEmpty)
          'region_code': regionCode,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
      options: _socialOptions,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendFriendRequestByNickname(
    String nickname,
  ) async {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    final r = await dio.post(
      '/friends/requests',
      data: {
        'nickname': normalized,
      },
      options: _socialOptions,
    );
    _invalidateNicknameLookup(normalized);
    await _invalidateProfileCaches();
    return r.data as Map<String, dynamic>;
  }

  /// Clears cached friends, groups, direct chats, and nickname lookups.
  Future<void> invalidateSocialCaches() => _invalidateProfileCaches();

  Future<Map<String, dynamic>> listFriendRequests() async {
    final r = await dio.get('/friends/requests');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondFriendRequest(
    String requestId,
    bool accept,
  ) async {
    final r = await dio.post(
      '/friends/requests/$requestId/respond',
      data: {
        'accept': accept,
      },
      options: _socialOptions,
    );
    if (accept) {
      await invalidateSocialCaches();
    }
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelFriendRequest(String requestId) async {
    final r = await dio.delete('/friends/requests/$requestId');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listFriends({bool forceRefresh = false}) async {
    final data = await _getCachedSWR(
      '/friends',
      ttl: friendsCacheTtl,
      forceRefresh: forceRefresh,
    ) as Map<String, dynamic>;
    return data['friends'] as List<dynamic>? ?? [];
  }

  // ----------------------------------------------------------- notifications
  Future<Map<String, dynamic>> listNotifications({
    String? before,
    int limit = 50,
  }) async {
    final r = await dio.get(
      '/notifications',
      queryParameters: {
        if (before != null) 'before': before,
        'limit': limit,
      },
      options: _socialOptions,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await dio.post('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await dio.post('/notifications/read-all');
  }

  Future<void> deleteNotification(String notificationId) async {
    await dio.delete('/notifications/$notificationId');
  }

  Future<void> clearAllNotifications() async {
    await dio.post('/notifications/clear');
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String provider = 'fcm',
  }) async {
    await dio.post('/devices/register', data: {
      'token': token,
      'platform': platform,
      'provider': provider,
    });
  }

  Future<void> unregisterDeviceToken(String token) async {
    await dio.post('/devices/unregister', data: {'token': token});
  }

  Future<List<dynamic>> listDirectChats({bool forceRefresh = false}) async {
    final data = await _getCachedSWR(
      '/direct-chats',
      ttl: inboxCacheTtl,
      forceRefresh: forceRefresh,
    ) as Map<String, dynamic>;
    return data['chats'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> markDirectChatRead(String friendId) async {
    final r = await dio.post(
      '/direct-chats/$friendId/read',
      options: _chatOptions,
    );
    await _invalidatePathCache('/direct-chats');
    await invalidateDirectMessagesCache(friendId);
    return r.data as Map<String, dynamic>;
  }

  /// Drop cached thread history so the next sync sees live messages/read state.
  Future<void> invalidateDirectMessagesCache(String friendId) async {
    await _invalidatePathCache(
      '/direct-chats/$friendId/messages',
      queryParameters: const {'limit': 50},
    );
  }

  Future<Map<String, dynamic>> directMessages(
    String friendId, {
    String? before,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final path = '/direct-chats/$friendId/messages';
    final query = {
      if (before != null) 'before': before,
      'limit': limit,
    };
    if (before == null) {
      final data = await _getCachedSWR(
        path,
        queryParameters: query,
        ttl: messagesCacheTtl,
        forceRefresh: forceRefresh,
      );
      return Map<String, dynamic>.from(data as Map);
    }
    final r = await dio.get(
      path,
      queryParameters: query,
      options: _chatOptions,
    );
    return r.data as Map<String, dynamic>;
  }

  /// Cached messages for instant chat paint (no network).
  Future<Map<String, dynamic>?> peekDirectMessagesCache(String friendId) async {
    final path = '/direct-chats/$friendId/messages';
    const query = {'limit': 50};
    final raw = await peekCache(path, queryParameters: query);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Prefetch thread history into memory/disk cache before opening the chat.
  Future<void> warmDirectMessagesCache(String friendId) async {
    if (peekDirectMessagesCacheSync(friendId) != null) return;
    try {
      await directMessages(friendId);
    } catch (_) {
      // Best-effort warm-up.
    }
  }

  /// Prefetch recent threads shown in the inbox list.
  Future<void> prefetchDirectMessageCaches(Iterable<String> friendIds) async {
    for (final friendId in friendIds) {
      if (peekDirectMessagesCacheSync(friendId) != null) continue;
      try {
        await directMessages(friendId);
      } catch (_) {
        // Continue warming other threads.
      }
    }
  }

  Future<Map<String, dynamic>> sendDirectMessage(
    String friendId,
    String body, {
    String msgtype = 'm.text',
    String? url,
    String? filename,
    String? contentType,
    int? sizeBytes,
    String? replyToId,
    String? clientId,
  }) async {
    final r = await dio.post(
      '/direct-chats/$friendId/messages',
      data: {
        'body': body,
        if (msgtype != 'm.text') 'msgtype': msgtype,
        if (url != null) 'url': url,
        if (filename != null) 'filename': filename,
        if (contentType != null) 'content_type': contentType,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (clientId != null) 'client_id': clientId,
      },
      options: _chatOptions,
    );
    await invalidateDirectMessagesCache(friendId);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> directToggleReaction(
    String messageId,
    String emoji,
  ) async {
    final r =
        await dio.post('/direct-chats/messages/$messageId/reactions', data: {
      'emoji': emoji,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> directChatUpload(
    String friendId, {
    required Uint8List bytes,
    required String filename,
    required String contentType,
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final r = await dio.post(
      '/direct-chats/$friendId/upload',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return r.data as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ chat
  Future<Map<String, dynamic>> chatSync(
    String groupId, {
    String? before,
    int limit = 50,
  }) async {
    final path = '/chat/$groupId/messages';
    final query = {
      if (before != null) 'before': before,
      'limit': limit,
    };
    if (before == null) {
      final data = await _getCached(path, queryParameters: query);
      return Map<String, dynamic>.from(data as Map);
    }
    final r = await dio.get(path, queryParameters: query);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatSendMessage(String groupId, String body,
      {String? clientId}) async {
    final r = await dio.post('/chat/$groupId/messages', data: {
      'body': body,
      if (clientId != null) 'client_id': clientId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatToggleReaction(
    String messageId,
    String emoji,
  ) async {
    final r = await dio.post('/chat/messages/$messageId/reactions', data: {
      'emoji': emoji,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatSendImage(
      String groupId, String mxcUrl) async {
    final r = await dio.post('/chat/send-image',
        data: {'group_id': groupId, 'mxc_url': mxcUrl});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatSendMedia(
    String groupId,
    Map<String, dynamic> upload, {
    required String msgtype,
    String? body,
  }) async {
    final r = await dio.post('/chat/$groupId/messages', data: {
      'msgtype': msgtype,
      'body': body ?? upload['filename'] ?? 'Вложение',
      'url': upload['mxc_url'] ?? upload['storage_url'],
      'filename': upload['filename'],
      'content_type': upload['content_type'],
      'size_bytes': upload['size_bytes'],
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatUploadMedia(
    String groupId,
    File file, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'group_id': groupId,
      'file': await MultipartFile.fromFile(file.path),
    });
    final r = await dio.post(
      '/chat/upload',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return r.data as Map<String, dynamic>;
  }

  /// Bytes-based group chat upload (image/file pending-attachment flow),
  /// mirroring [directChatUpload] with real cancellation support.
  Future<Map<String, dynamic>> chatUploadMediaBytes(
    String groupId, {
    required Uint8List bytes,
    required String filename,
    required String contentType,
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'group_id': groupId,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final r = await dio.post(
      '/chat/upload',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return r.data as Map<String, dynamic>;
  }
}

class _MemoryCacheEntry {
  const _MemoryCacheEntry(this.data, this.fetchedAt);

  final dynamic data;
  final DateTime fetchedAt;
}
