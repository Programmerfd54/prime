import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Shared Axis / FadeThrough route helpers for premium page transitions.
abstract final class PrimeRoute {
  static Route<T> sharedAxis<T>({
    required WidgetBuilder builder,
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
    );
  }

  static Route<T> fadeThrough<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}

/// PageTransitionsTheme wiring SharedAxis for Material navigations.
PageTransitionsTheme get primePageTransitionsTheme => const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SharedAxisPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: _SharedAxisPageTransitionsBuilder(),
        TargetPlatform.windows: _SharedAxisPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _SharedAxisPageTransitionsBuilder(),
      },
    );

class _SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      child: child,
    );
  }
}
