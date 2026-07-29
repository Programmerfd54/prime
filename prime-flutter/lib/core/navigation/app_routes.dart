import 'package:flutter/material.dart';

import '../../design/routes.dart' as design;
import '../../screens/account_settings_screen.dart';
import '../../screens/avatar_screen.dart';
import '../../screens/group_detail_screen.dart';
import 'app_gate.dart';
import 'route_loaders.dart';

/// Central route table for PRIME.
///
/// Navigator 2.0-lite: we keep `Navigator.push`/`pushNamed` (no go_router),
/// but every screen is now reachable by a stable, named, refresh-safe URL
/// via [onGenerateRoute] / [onGenerateInitialRoutes]. This is what makes web
/// deep links and browser refresh work: on a hard refresh, Flutter re-reads
/// the current browser path and calls [onGenerateInitialRoutes] with it, so
/// the correct screen (and a sane back-stack) gets rebuilt from scratch.
///
/// [AppGate] remains the single authority over the onboarding → auth →
/// profile-setup → [MainShell] flow: named routes never render an
/// authenticated screen directly, they only ask the gate to preselect a
/// [MainShell] tab (see [tabIndexForRoute]) once the user is actually
/// signed in.
abstract final class AppRoutes {
  const AppRoutes._();

  // Top-level / tab routes -----------------------------------------------
  static const home = '/';
  static const homeAlias = '/home';
  static const skills = '/skills';
  static const groups = '/groups';
  static const chats = '/chats';
  static const profile = '/profile';
  static const settings = '/settings';
  static const avatar = '/avatar';
  static const auth = '/auth';
  static const onboarding = '/onboarding';

  // Detail route prefixes (`<prefix><id>`) --------------------------------
  static const _groupPrefix = '/group/';
  static const _skillDetailPrefix = '/skills/';
  static const _chatGroupPrefix = '/chat/group/';
  static const _chatDirectPrefix = '/chat/direct/';
  static const _publicProfilePrefix = '/profile/';

  static String groupDetailPath(String groupId) => '$_groupPrefix$groupId';

  static String skillDetailPath(String skillId) =>
      '$_skillDetailPrefix$skillId';

  static String chatGroupPath(String groupId) => '$_chatGroupPrefix$groupId';

  static String chatDirectPath(String friendId) =>
      '$_chatDirectPrefix$friendId';

  static String publicProfilePath(String userId) =>
      '$_publicProfilePrefix$userId';

  /// Maps a top-level tab route to the [MainShell] tab index it represents,
  /// matching `_navItems` order in `main_shell.dart` (Skills, Groups, Home,
  /// Chats, Profile). Returns null for routes that aren't tabs.
  static int? tabIndexForRoute(String path) {
    switch (path) {
      case skills:
        return 0;
      case groups:
        return 1;
      case home:
      case homeAlias:
        return 2;
      case chats:
        return 3;
      case profile:
        return 4;
      default:
        return null;
    }
  }

  static String _pathOf(String routeName) {
    final uri = Uri.tryParse(routeName);
    final path = uri?.path ?? routeName;
    return path.isEmpty ? home : path;
  }

  static bool _isDetailRoute(String path) =>
      path.startsWith(_groupPrefix) ||
      path.startsWith(_skillDetailPrefix) ||
      path.startsWith(_chatGroupPrefix) ||
      path.startsWith(_chatDirectPrefix) ||
      path.startsWith(_publicProfilePrefix) ||
      path == settings ||
      path == avatar;

  /// Builds the widget + transition for a single named route.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final path = _pathOf(settings.name ?? home);
    final page = _pageFor(path);
    return design.PrimeRoute.sharedAxis(
      builder: (_) => page,
      settings: RouteSettings(name: path, arguments: settings.arguments),
    );
  }

  /// Rebuilds the full back-stack for a fresh app start (cold start on
  /// mobile, or a hard browser refresh on web with [design.PrimeRoute]s).
  ///
  /// Tab routes (`/groups`, `/chats`, ...) resolve to a single [AppGate]
  /// entry with the tab preselected. Detail routes (`/group/:id`, chats,
  /// profiles, settings, avatar) are rebuilt on top of a home entry so the
  /// back button still returns to [MainShell] instead of exiting the app.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    final path = _pathOf(initialRoute);
    if (!_isDetailRoute(path)) {
      return [onGenerateRoute(RouteSettings(name: path))];
    }
    return [
      onGenerateRoute(const RouteSettings(name: home)),
      onGenerateRoute(RouteSettings(name: path)),
    ];
  }

  static Widget _pageFor(String path) {
    if (path == home || path == homeAlias) {
      return const AppGate();
    }
    final tabIndex = tabIndexForRoute(path);
    if (tabIndex != null) {
      return AppGate(initialTabIndex: tabIndex);
    }
    // The gate stays authoritative for the auth flow itself: these routes
    // just give it a stable, linkable URL rather than rendering the raw
    // screen (which would ignore the user's actual session state).
    if (path == auth || path == onboarding) {
      return const AppGate();
    }
    if (path == settings) {
      return const AccountSettingsScreen();
    }
    if (path == avatar) {
      return const AvatarScreen();
    }
    if (path.startsWith(_groupPrefix)) {
      final id = path.substring(_groupPrefix.length);
      return GroupDetailScreen(groupId: id);
    }
    if (path.startsWith(_skillDetailPrefix)) {
      final id = path.substring(_skillDetailPrefix.length);
      return SkillDetailRouteLoader(skillId: id);
    }
    if (path.startsWith(_chatGroupPrefix)) {
      final id = path.substring(_chatGroupPrefix.length);
      return GroupChatRouteLoader(groupId: id);
    }
    if (path.startsWith(_chatDirectPrefix)) {
      final id = path.substring(_chatDirectPrefix.length);
      return DirectChatRouteLoader(friendId: id);
    }
    if (path.startsWith(_publicProfilePrefix)) {
      final id = path.substring(_publicProfilePrefix.length);
      return PublicProfileRouteLoader(userId: id);
    }
    return const AppGate();
  }
}

/// Small helpers for the common pushes, so call sites can read intent
/// (`AppNavigator.pushSkillDetail(...)`) instead of raw path strings.
/// Existing `Navigator.push(PrimeRoute.sharedAxis(...))` call sites keep
/// working unchanged; these are opt-in.
abstract final class AppNavigator {
  const AppNavigator._();

  static Future<T?> pushSkillDetail<T>(BuildContext context, String skillId) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.skillDetailPath(skillId),
    );
  }

  static Future<T?> pushGroupDetail<T>(BuildContext context, String groupId) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.groupDetailPath(groupId),
    );
  }

  static Future<T?> pushGroupChat<T>(BuildContext context, String groupId) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.chatGroupPath(groupId),
    );
  }

  static Future<T?> pushDirectChat<T>(BuildContext context, String friendId) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.chatDirectPath(friendId),
    );
  }

  static Future<T?> pushPublicProfile<T>(
    BuildContext context,
    String userId,
  ) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.publicProfilePath(userId),
    );
  }

  static Future<T?> pushSettings<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.settings);
  }

  static Future<T?> pushAvatar<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.avatar);
  }
}
