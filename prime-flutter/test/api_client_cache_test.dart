import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime/data/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('sensitive API cache paths', () {
    test('direct-chats responses stay memory-only', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter({
        '/direct-chats': {'chats': []},
      });

      await api.listDirectChats();

      final prefs = await SharedPreferences.getInstance();
      expect(_diskCacheKeys(prefs), isEmpty);
      expect(api.peekMemoryCacheSync('/direct-chats'), isNotNull);
      api.dispose();
    });

    test('friends responses stay memory-only', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter({
        '/friends': {'friends': []},
      });

      await api.listFriends();

      final prefs = await SharedPreferences.getInstance();
      expect(_diskCacheKeys(prefs), isEmpty);
      expect(api.peekMemoryCacheSync('/friends'), isNotNull);
      api.dispose();
    });

    test('direct chat messages stay memory-only', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter({
        '/direct-chats/friend-1/messages': {'messages': [], 'has_more': false},
      });

      await api.directMessages('friend-1');

      final prefs = await SharedPreferences.getInstance();
      expect(_diskCacheKeys(prefs), isEmpty);
      expect(
        api.peekDirectMessagesCacheSync('friend-1'),
        isNotNull,
      );
      api.dispose();
    });

    test('group chat messages stay memory-only', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter({
        '/chat/group-1/messages': {'messages': [], 'has_more': false},
      });

      await api.chatSync('group-1');

      final prefs = await SharedPreferences.getInstance();
      expect(_diskCacheKeys(prefs), isEmpty);
      expect(
        api.peekMemoryCacheSync(
          '/chat/group-1/messages',
          queryParameters: const {'limit': 50},
        ),
        isNotNull,
      );
      api.dispose();
    });

    test('non-sensitive paths still persist to disk', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter({
        '/groups': [
          {'id': 'g1', 'name': 'Team'},
        ],
      });

      await api.listGroups();

      final prefs = await SharedPreferences.getInstance();
      expect(_diskCacheKeys(prefs), isNotEmpty);
      api.dispose();
    });
  });
}

Iterable<String> _diskCacheKeys(SharedPreferences prefs) {
  return prefs.getKeys().where((key) => key.startsWith('prime_api_cache_v1:'));
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this._responses);

  final Map<String, dynamic> _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final payload = _responses[path];
    if (payload == null) {
      return ResponseBody.fromString(
        '{"detail":"Not Found"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
