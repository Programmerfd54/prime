/// Content-oriented breakpoints for adaptive layouts.
///
/// Complements [AppBreakpoints] used by MainShell (phone shell / tablet rail).
abstract final class PrimeBreakpoints {
  /// Compact phone layouts.
  static const compact = 600.0;

  /// Tablet / medium.
  static const medium = 1024.0;

  /// Expanded desktop.
  static const expanded = 1024.0;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= expanded;
}
