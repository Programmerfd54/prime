import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'config/theme.dart';
import 'core/errors/app_error_boundary.dart';
import 'core/navigation/app_routes.dart';
import 'core/profile/theme_mode_controller.dart';
import 'core/sync/realtime_client.dart';
import 'core/sync/waiting_room_poller.dart';
import 'data/api_client.dart';
import 'design/forui_theme.dart';
import 'design/routes.dart';
import 'design/scroll_behavior.dart';
import 'design/theme/prime_theme_context.dart';
import 'design/tokens.dart';
import 'providers/auth_provider.dart';

void main() {
  // Bindings and runApp must share one zone (avoids Zone mismatch on web).
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    installAppErrorBoundary();
    // Path-style URLs on web (e.g. /group/abc123 instead of /#/group/abc123)
    // so deep links and browser refresh work. `usePathUrlStrategy()` is a
    // documented no-op on non-web platforms (flutter_web_plugins swaps in a
    // stub implementation via conditional export), but we gate on kIsWeb
    // too for clarity/defense-in-depth.
    if (kIsWeb) {
      usePathUrlStrategy();
    }
    runApp(const PrimeApp());
  }, (error, stack) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.receiveTimeout)) {
      if (kDebugMode) {
        debugPrint('Network (handled): $error');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('Zone error: $error\n$stack');
    }
  });
}

class PrimeApp extends StatelessWidget {
  const PrimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeModeController>(
          create: (_) => ThemeModeController(),
        ),
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, api) => api.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) {
            final auth = AuthProvider(ctx.read<ApiClient>());
            unawaited(
              auth.init().catchError((Object e, StackTrace st) {
                if (kDebugMode) {
                  debugPrint('Auth init (swallowed): $e');
                }
              }),
            );
            return auth;
          },
        ),
        ChangeNotifierProvider<WaitingRoomPoller>(
          create: (ctx) => WaitingRoomPoller(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<RealtimeClient>(
          create: (ctx) => RealtimeClient(ctx.read<ApiClient>()),
        ),
      ],
      child: Consumer<ThemeModeController>(
        builder: (context, themeCtrl, _) {
          final mode = themeCtrl.mode;
          return ShadApp.custom(
            themeMode: mode,
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: ShadSlateColorScheme.light(
                primary: AppColors.primary,
                background: Color(0xFFF8F7FA),
                foreground: Color(0xFF1A1622),
                card: Color(0xFFFFFFFF),
                border: Color(0x141A1622),
              ),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: ShadSlateColorScheme.dark(
                primary: AppColors.primary,
                background: AppColors.background,
                foreground: AppColors.textPrimary,
                card: AppColors.surface,
                border: AppColors.border,
              ),
            ),
            appBuilder: (context) => MaterialApp(
              title: 'ПРАЙМ',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: AppTheme.light.copyWith(
                pageTransitionsTheme: primePageTransitionsTheme,
              ),
              darkTheme: AppTheme.dark.copyWith(
                pageTransitionsTheme: primePageTransitionsTheme,
              ),
              scrollBehavior: const PrimeScrollBehavior(),
              localizationsDelegates: FLocalizations.localizationsDelegates,
              supportedLocales: FLocalizations.supportedLocales,
              builder: (context, child) {
                final brightness = Theme.of(context).brightness;
                ThemeBinding.bind(brightness);
                final prime = context.prime;
                return FTheme(
                  data: primeForuiTheme(prime),
                  child: FToaster(
                    child: FTooltipGroup(
                      child: ShadAppBuilder(
                        backgroundColor: Colors.transparent,
                        child: _DesktopWebFrame(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                );
              },
              initialRoute:
                  WidgetsBinding.instance.platformDispatcher.defaultRouteName,
              onGenerateInitialRoutes: AppRoutes.onGenerateInitialRoutes,
              onGenerateRoute: AppRoutes.onGenerateRoute,
            ),
          );
        },
      ),
    );
  }
}

/// Роутинг: onboarding → auth → main shell.
class _DesktopWebFrame extends StatelessWidget {
  final Widget child;

  const _DesktopWebFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final canvas = context.prime.canvas;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= AppBreakpoints.tablet;
        final framed = constraints.maxWidth < AppBreakpoints.phoneShell
            ? child
            : ColoredBox(
                color: canvas,
                child: Center(
                  child: SizedBox(
                    width: isTablet
                        ? constraints.maxWidth.clamp(
                            AppBreakpoints.tablet,
                            1200,
                          )
                        : AppBreakpoints.maxContentWidth,
                    height: constraints.maxHeight,
                    child: ClipRect(child: child),
                  ),
                ),
              );

        return Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: framed,
        );
      },
    );
  }
}
