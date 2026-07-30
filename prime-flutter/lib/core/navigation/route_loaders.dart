import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../models/group.dart';
import '../../models/skill.dart';
import '../../models/user.dart';
import '../../screens/direct_chat_screen.dart';
import '../../screens/group_chat_screen.dart';
import '../../screens/public_profile_screen.dart';
import '../../screens/skills_screen.dart';
import '../../ui/states/app_loading_state.dart';
import '../../widgets/async_error_view.dart';

/// Deep links (e.g. a hard refresh on web, or a cold-start intent) only
/// carry an id in the URL, but the target screens below require a fully
/// hydrated model object because that's how they're pushed everywhere else
/// in the app. These loaders bridge that gap: fetch by id, then hand off to
/// the existing, unmodified screen widget.
abstract class _ByIdRouteLoader<T> extends StatefulWidget {
  const _ByIdRouteLoader({super.key});

  Future<T> load(BuildContext context);

  Widget buildScreen(BuildContext context, T value);

  String get notFoundMessage;

  @override
  State<_ByIdRouteLoader<T>> createState() => _ByIdRouteLoaderState<T>();
}

class _ByIdRouteLoaderState<T> extends State<_ByIdRouteLoader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load(context);
  }

  void _retry() {
    setState(() => _future = widget.load(context));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: AppLoadingState());
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: AsyncErrorView(
              message: widget.notFoundMessage,
              onRetry: () async => _retry(),
            ),
          );
        }
        return widget.buildScreen(context, snapshot.data as T);
      },
    );
  }
}

/// Resolves `/skills/:id` into a [SkillDetailScreen].
class SkillDetailRouteLoader extends _ByIdRouteLoader<List<SkillModel>> {
  const SkillDetailRouteLoader({super.key, required this.skillId});

  final String skillId;

  @override
  String get notFoundMessage => 'Программа не найдена';

  @override
  Future<List<SkillModel>> load(BuildContext context) async {
    final raw = await context.read<ApiClient>().listSkills();
    return raw.cast<Map<String, dynamic>>().map(SkillModel.fromJson).toList();
  }

  @override
  Widget buildScreen(BuildContext context, List<SkillModel> skills) {
    SkillModel? match;
    for (final skill in skills) {
      if (skill.id == skillId) {
        match = skill;
        break;
      }
    }
    if (match == null) {
      return Scaffold(
        body: AsyncErrorView(
          message: notFoundMessage,
          onRetry: () async {},
        ),
      );
    }
    return SkillDetailScreen(skill: match, allSkills: skills);
  }
}

/// Resolves `/chat/group/:id` into a [GroupChatScreen] (needs the group
/// name, so the group is fetched first).
class GroupChatRouteLoader extends _ByIdRouteLoader<GroupModel> {
  const GroupChatRouteLoader({super.key, required this.groupId});

  final String groupId;

  @override
  String get notFoundMessage => 'Группа не найдена';

  @override
  Future<GroupModel> load(BuildContext context) async {
    final raw = await context.read<ApiClient>().getGroup(groupId);
    return GroupModel.fromJson(raw);
  }

  @override
  Widget buildScreen(BuildContext context, GroupModel group) {
    return GroupChatScreen(
      groupId: group.id,
      groupName: group.skillName ?? group.name,
    );
  }
}

/// Resolves `/chat/direct/:friendId` into a [DirectChatScreen]. Only the
/// friends list is searchable through the current API surface, so
/// non-friends will surface [notFoundMessage] instead of a chat.
class DirectChatRouteLoader extends _ByIdRouteLoader<UserPublic?> {
  const DirectChatRouteLoader({super.key, required this.friendId});

  final String friendId;

  @override
  String get notFoundMessage => 'Друг не найден';

  @override
  Future<UserPublic?> load(BuildContext context) async {
    return _resolveFriend(context.read<ApiClient>(), friendId);
  }

  @override
  Widget buildScreen(BuildContext context, UserPublic? friend) {
    if (friend == null) {
      return Scaffold(
        body: AsyncErrorView(message: notFoundMessage, onRetry: () async {}),
      );
    }
    return DirectChatScreen(friend: friend);
  }
}

Future<UserPublic?> _resolveFriend(ApiClient api, String friendId) async {
  UserPublic? fromRows(List<dynamic> rows) {
    for (final row in rows.whereType<Map>()) {
      final friend = UserPublic.fromJson(Map<String, dynamic>.from(row));
      if (friend.id == friendId) return friend;
    }
    return null;
  }

  final cached = await api.peekCache('/friends');
  if (cached is Map<String, dynamic>) {
    final hit = fromRows(cached['friends'] as List<dynamic>? ?? []);
    if (hit != null) return hit;
  }

  final rows = await api.listFriends();
  return fromRows(rows);
}

/// Resolves `/profile/:userId` into a [PublicProfileScreen]. Best-effort via
/// the friends list, same caveat as [DirectChatRouteLoader].
class PublicProfileRouteLoader extends _ByIdRouteLoader<UserPublic?> {
  const PublicProfileRouteLoader({super.key, required this.userId});

  final String userId;

  @override
  String get notFoundMessage => 'Профиль недоступен';

  @override
  Future<UserPublic?> load(BuildContext context) async {
    return _resolveFriend(context.read<ApiClient>(), userId);
  }

  @override
  Widget buildScreen(BuildContext context, UserPublic? profile) {
    if (profile == null) {
      return Scaffold(
        body: AsyncErrorView(message: notFoundMessage, onRetry: () async {}),
      );
    }
    return PublicProfileScreen(profile: profile);
  }
}
