import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import 'regions.dart';

class ApiClient {
  static const _cachePrefix = 'prime_api_cache_v1:';

  /// Default HTTP timeouts — chat endpoints may use [chatDioOptions].
  static const defaultConnectTimeout = Duration(seconds: 25);
  static const defaultSendTimeout = Duration(seconds: 30);
  static const defaultReceiveTimeout = Duration(seconds: 45);

  late final Dio dio;

  /// Called once when a mid-session 401 is observed (not login/register).
  void Function()? onUnauthorized;

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
        onError: (error, handler) {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          // Never treat public auth endpoints as mid-session expiry.
          final isAuthEndpoint = path.contains('/auth/');
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
    final userScope =
        auth.length > 18 ? auth.substring(auth.length - 18) : auth;
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
      await _saveCache(key, r.data);
      return r.data;
    } on DioException catch (error) {
      if (isUnauthorized(error) || !isNetworkError(error)) rethrow;
      final cached = await _readCache(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> clearResponseCache() async {
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

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final r = await dio.patch('/users/me', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await dio.delete('/users/me');
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
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> nudgeGroup(String groupId) async {
    final r = await dio.post('/groups/$groupId/nudge');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listGroups() async {
    final r = await dio.get('/groups');
    return r.data as List<dynamic>;
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

  Future<Map<String, dynamic>> calendarAll() async {
    final r = await dio.get('/reports/calendar/all');
    return r.data as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------ achievements
  Future<List<dynamic>> listAchievements() async {
    return await _getCached('/achievements') as List<dynamic>;
  }

  // ------------------------------------------------------------------ friends
  Future<Map<String, dynamic>> findUserByNickname(String nickname) async {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    final r = await dio.get('/users/by-nickname/$normalized');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendFriendRequestByNickname(
    String nickname,
  ) async {
    final normalized = nickname.trim().replaceFirst(RegExp(r'^@'), '');
    final r = await dio.post('/friends/requests', data: {
      'nickname': normalized,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listFriendRequests() async {
    final r = await dio.get('/friends/requests');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondFriendRequest(
    String requestId,
    bool accept,
  ) async {
    final r = await dio.post('/friends/requests/$requestId/respond', data: {
      'accept': accept,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelFriendRequest(String requestId) async {
    final r = await dio.delete('/friends/requests/$requestId');
    return r.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listFriends() async {
    final r = await dio.get('/friends');
    final data = r.data as Map<String, dynamic>;
    return data['friends'] as List<dynamic>? ?? [];
  }

  // ----------------------------------------------------------- notifications
  Future<Map<String, dynamic>> listNotifications() async {
    final r = await dio.get('/notifications');
    return r.data as Map<String, dynamic>;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await dio.post('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await dio.post('/notifications/read-all');
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await dio.post('/devices/register', data: {
      'token': token,
      'platform': platform,
    });
  }

  Future<List<dynamic>> listDirectChats() async {
    final data = await _getCached('/direct-chats') as Map<String, dynamic>;
    return data['chats'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> markDirectChatRead(String friendId) async {
    final r = await dio.post('/direct-chats/$friendId/read');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> directMessages(
    String friendId, {
    String? before,
    int limit = 50,
  }) async {
    final path = '/direct-chats/$friendId/messages';
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
    final r = await dio.post('/direct-chats/$friendId/messages', data: {
      'body': body,
      if (msgtype != 'm.text') 'msgtype': msgtype,
      if (url != null) 'url': url,
      if (filename != null) 'filename': filename,
      if (contentType != null) 'content_type': contentType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (clientId != null) 'client_id': clientId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> directToggleReaction(
    String messageId,
    String emoji,
  ) async {
    final r = await dio.post('/direct-chats/messages/$messageId/reactions', data: {
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

  Future<Map<String, dynamic>> chatSendMessage(
    String groupId,
    String body,
  ) async {
    final r = await dio.post('/chat/$groupId/messages', data: {'body': body});
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
