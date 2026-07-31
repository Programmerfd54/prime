import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'app_gate.dart';

/// Wraps a deep-link target and defers to [AppGate] when there is no session.
class AuthRequiredRoute extends StatelessWidget {
  const AuthRequiredRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      return const AppGate();
    }
    return child;
  }
}
