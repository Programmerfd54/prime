import 'package:flutter/material.dart';

import '../../design/theme/prime_theme_context.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/visuals/ambient_and_progress.dart';
import '../components/editorial/app_auth_hero.dart';
import '../kit/presentation/profile_surfaces.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label,
    this.showBrand = false,
  });

  final String? label;

  /// Boot / splash — editorial brand mark with ambient canvas.
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    if (showBrand) {
      return _AppBootSplash(label: label);
    }
    return _InlineLoading(label: label);
  }
}

class _AppBootSplash extends StatelessWidget {
  const _AppBootSplash({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return ColoredBox(
      color: ProfileSurfaces.canvas,
      child: AmbientCanvas(
        intensity: 0.85,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PrimeBrandMark(size: 76),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'ПРАЙМ',
                  style: AppTypography.caption.copyWith(
                    color: p.brandSoft.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                    height: 1,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary.copyWith(
                      color: p.inkMuted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const _BootDotsIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootDotsIndicator extends StatefulWidget {
  const _BootDotsIndicator();

  @override
  State<_BootDotsIndicator> createState() => _BootDotsIndicatorState();
}

class _BootDotsIndicatorState extends State<_BootDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1.0;
            final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            final opacity = 0.28 + t * 0.72;
            final scale = 0.82 + t * 0.18;
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.brand.withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return ColoredBox(
      color: ProfileSurfaces.canvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.25,
                color: p.brand.withValues(alpha: 0.85),
                backgroundColor: p.hairline.withValues(alpha: 0.35),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary.copyWith(color: p.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
