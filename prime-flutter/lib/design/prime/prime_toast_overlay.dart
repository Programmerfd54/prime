import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/prime/prime_glass_surface.dart';
import '../../design/theme/prime_colors.dart';
import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

enum PrimeToastVariant { success, error, warning, info, loading }

class PrimeToastAction {
  const PrimeToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// V5 overlay toast — dark glass, status icon, swipe to dismiss.
abstract final class PrimeToastOverlay {
  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context,
    String message, {
    PrimeToastVariant variant = PrimeToastVariant.info,
    Duration duration = const Duration(seconds: 3),
    PrimeToastAction? action,
  }) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) => _PrimeToastHost(
        message: message,
        variant: variant,
        duration: duration,
        action: action,
        onDismiss: hide,
      ),
    );
    overlay.insert(_entry!);

    if (variant != PrimeToastVariant.loading) {
      _hideTimer = Timer(duration, hide);
    }
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// Shows a loading toast if [future] takes longer than [threshold].
Future<T> withSlowActionNotice<T>(
  BuildContext context,
  Future<T> future, {
  Duration threshold = const Duration(milliseconds: 2500),
  String message = 'Долго грузится, ждём сервер',
}) async {
  Timer? timer;
  var shown = false;
  timer = Timer(threshold, () {
    if (!context.mounted) return;
    shown = true;
    PrimeToastOverlay.show(
      context,
      message,
      variant: PrimeToastVariant.loading,
      duration: const Duration(seconds: 30),
    );
  });
  try {
    return await future;
  } finally {
    timer.cancel();
    if (shown && context.mounted) PrimeToastOverlay.hide();
  }
}

class _PrimeToastHost extends StatefulWidget {
  const _PrimeToastHost({
    required this.message,
    required this.variant,
    required this.duration,
    required this.onDismiss,
    this.action,
  });

  final String message;
  final PrimeToastVariant variant;
  final Duration duration;
  final VoidCallback onDismiss;
  final PrimeToastAction? action;

  @override
  State<_PrimeToastHost> createState() => _PrimeToastHostState();
}

class _PrimeToastHostState extends State<_PrimeToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.variant) {
        PrimeToastVariant.success => Icons.check_circle_rounded,
        PrimeToastVariant.error => Icons.error_outline_rounded,
        PrimeToastVariant.warning => Icons.warning_amber_rounded,
        PrimeToastVariant.loading => Icons.hourglass_top_rounded,
        PrimeToastVariant.info => Icons.info_outline_rounded,
      };

  Color _accent(PrimeColors p) => switch (widget.variant) {
        PrimeToastVariant.success => p.mint,
        PrimeToastVariant.error => p.coral,
        PrimeToastVariant.warning => p.gold,
        PrimeToastVariant.loading => p.brandSoft,
        PrimeToastVariant.info => p.brandSoft,
      };

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom + 88 + _drag.clamp(-120.0, 0.0),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: FadeTransition(
          opacity: _controller,
          child: GestureDetector(
            onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
            onVerticalDragEnd: (d) {
              if (_drag < -36 || d.velocity.pixelsPerSecond.dy < -400) {
                unawaited(_dismiss());
              } else {
                setState(() => _drag = 0);
              }
            },
            child: Material(
              color: Colors.transparent,
              child: PrimeGlassSurface(
                variant: PrimeGlassVariant.contextMenu,
                radius: AppRadius.lg,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (widget.variant == PrimeToastVariant.loading)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent(p),
                        ),
                      )
                    else
                      Icon(_icon, color: _accent(p), size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.body.copyWith(color: p.ink),
                      ),
                    ),
                    if (widget.action != null)
                      TextButton(
                        onPressed: () {
                          widget.action!.onPressed();
                          unawaited(_dismiss());
                        },
                        child: Text(
                          widget.action!.label,
                          style: AppTypography.button.copyWith(color: p.brand),
                        ),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, color: p.inkMuted, size: 18),
                      onPressed: () => unawaited(_dismiss()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
