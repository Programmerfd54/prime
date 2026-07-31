import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';

typedef NativePushOpenCallback = void Function(Map<String, dynamic> payload);

/// Connects native APNs / Android push lifecycle to the authenticated PRIME API.
class NativePushService {
  NativePushService._();

  static final NativePushService instance = NativePushService._();
  static const MethodChannel _channel = MethodChannel('prime/native_push');

  ApiClient? _api;
  NativePushOpenCallback? _onOpen;
  bool _handlerInstalled = false;
  bool _registrationRequested = false;
  String? _lastRegisteredToken;
  bool degraded = false;

  Future<void> start(
    ApiClient api, {
    required NativePushOpenCallback onOpen,
  }) async {
    _api = api;
    _onOpen = onOpen;
    if (kIsWeb) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler(_handleNativeCall);
    }
    if (_registrationRequested) return;
    _registrationRequested = true;
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'requestAuthorization',
      );
      degraded = response?['degraded'] as bool? ?? false;
      final granted = response?['granted'] as bool? ?? true;
      final token = response?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      } else if (!degraded && granted) {
        // Permission granted but token not ready yet — onTokenRefresh will follow.
        degraded = false;
      }
      final pending = response?['pending_notification'];
      if (pending is Map) {
        _onOpen?.call(Map<String, dynamic>.from(pending));
      }
    } on MissingPluginException {
      degraded = true;
    } on PlatformException catch (error) {
      degraded = true;
      if (kDebugMode) {
        debugPrint('Native push registration unavailable: ${error.code}');
      }
    }
  }

  void stop() {
    _onOpen = null;
  }

  Future<void> unregister() async {
    final token = _lastRegisteredToken;
    final api = _api;
    if (token != null && api != null && api.authToken != null) {
      try {
        await api.unregisterDeviceToken(token);
      } catch (_) {}
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        await _channel.invokeMethod<void>('disableNotifications');
      } on MissingPluginException {
      } on PlatformException {}
    }
    _lastRegisteredToken = null;
    _registrationRequested = false;
    degraded = false;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    final arguments = call.arguments;
    final payload = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : <String, dynamic>{};
    switch (call.method) {
      case 'token':
        final token = payload['token'] as String? ?? '';
        if (token.isNotEmpty) await _registerToken(token);
        return;
      case 'notificationOpened':
        _onOpen?.call(payload);
        return;
      case 'notificationAction':
        await _handleAction(payload);
        return;
      default:
        return;
    }
  }

  Future<void> _handleAction(Map<String, dynamic> payload) async {
    final action = payload['action'] as String? ?? 'open';
    final skillId = payload['skill_id'] as String?;
    if (action == 'confirm' && skillId != null && skillId.isNotEmpty) {
      try {
        await _api?.confirmEarlyStart(skillId: skillId);
      } catch (_) {}
    }
    if (action != 'keep_waiting') {
      _onOpen?.call(payload);
    }
  }

  Future<void> _registerToken(String token) async {
    if (_lastRegisteredToken == token) return;
    final api = _api;
    if (api == null || api.authToken == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final provider = Platform.isIOS ? 'apns' : 'fcm';
    try {
      await api.registerDeviceToken(
        token: token,
        platform: platform,
        provider: provider,
      );
      _lastRegisteredToken = token;
      degraded = false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Native push token registration failed: ${error.runtimeType}',
        );
      }
    }
  }
}
