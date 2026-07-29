import 'package:flutter/material.dart';

/// Global bouncing scroll — Apple-like fluidity on Android & Web.
class PrimeScrollBehavior extends MaterialScrollBehavior {
  const PrimeScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
