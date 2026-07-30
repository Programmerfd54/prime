import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/copy.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/profile_setup_screen.dart';
import '../../ui/kit/presentation/profile_surfaces.dart';
import '../../ui/states/app_loading_state.dart';
import '../../widgets/async_error_view.dart';

/// Auth router: onboarding → auth → profile setup → [MainShell].
///
/// This is the single source of truth for which top-level screen is shown;
/// named routes never bypass it, they only ask it to preselect a
/// [MainShell] tab once the user is actually authenticated.
class AppGate extends StatelessWidget {
  const AppGate({super.key, this.initialTabIndex});

  /// Tab to preselect inside [MainShell] once the gate resolves to it,
  /// e.g. when the app was opened via a `/groups` or `/chats` deep link.
  final int? initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.initializing) {
      return Scaffold(
        backgroundColor: ProfileSurfaces.canvas,
        body: const AppLoadingState(
          showBrand: true,
          label: 'Собираем ваш день…',
        ),
      );
    }
    if (auth.initializationError != null) {
      return Scaffold(
        body: AsyncErrorView(
          message: auth.initializationError!,
          onRetry: auth.retryInit,
        ),
      );
    }
    if (!auth.onboardingDone) return const OnboardingScreen();
    if (!auth.isAuthenticated) {
      if (auth.sessionExpiredNotice) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          auth.clearSessionExpiredNotice();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppCopy.unauthorized)),
          );
        });
      }
      return AuthScreen(startInLogin: auth.preferLoginOnAuth);
    }
    if (auth.user?.profileCompleted != true) {
      return const ProfileSetupScreen();
    }
    return MainShell(initialTabIndex: initialTabIndex);
  }
}
