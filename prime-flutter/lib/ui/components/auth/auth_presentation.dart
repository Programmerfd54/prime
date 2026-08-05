import 'package:flutter/material.dart';

import '../../../design/haptics.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../kit/components/prime_content_card.dart';
import '../../kit/tokens/kit_typography.dart';
import '../editorial/app_auth_hero.dart';
import '../../states/app_loading_state.dart';

/// Auth flow shell — ambient canvas, max width, optional loading.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.child,
    this.loading = false,
    this.loadingLabel = 'Подключаем ПРАЙМ…',
    this.appBar,
  });

  final Widget child;
  final bool loading;
  final String loadingLabel;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Scaffold(
      backgroundColor: p.canvas,
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      body: SafeArea(
        child: loading
            ? AppLoadingState(label: loadingLabel)
            : AmbientCanvas(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Gradient hero banner for auth screens.
class AuthHeroBanner extends StatelessWidget {
  const AuthHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.badge,
  });

  final String title;
  final String subtitle;
  final bool compact;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    p.brand.withValues(alpha: p.isDark ? 0.42 : 0.28),
                    p.brandContainer.withValues(alpha: p.isDark ? 0.55 : 0.38),
                    p.surfaceElevated.withValues(alpha: p.isDark ? 0.92 : 0.96),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              compact ? AppSpacing.md : AppSpacing.lg,
              AppSpacing.lg,
              compact ? AppSpacing.lg : AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimeBrandMark(size: compact ? 56 : 72),
                    const Spacer(),
                    if (badge != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          child: Text(
                            badge!,
                            style: KitTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                Text(
                  'ПРАЙМ',
                  style: KitTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  title,
                  style: AppTypography.pageTitle.copyWith(
                    color: Colors.white,
                    fontSize: compact ? 26 : 30,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: KitTypography.bodySecondary.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Register flow step indicator — 4 labeled steps.
class AuthRegisterStepper extends StatelessWidget {
  const AuthRegisterStepper({super.key, required this.step});

  final int step;

  static const _labels = ['Профиль', 'Доступ', 'Старт', 'Код'];
  static const _icons = [
    Icons.badge_outlined,
    Icons.lock_outline_rounded,
    Icons.rocket_launch_outlined,
    Icons.mark_email_read_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Шаг ${step + 1} из ${_labels.length} · ${_labels[step]}',
          style: KitTypography.caption.copyWith(color: p.brandSoft),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: i <= step
                        ? p.brand.withValues(alpha: 0.45)
                        : p.hairline,
                  ),
                ),
              _StepNode(
                index: i,
                current: step,
                label: _labels[i],
                icon: _icons[i],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.current,
    required this.label,
    required this.icon,
  });

  final int index;
  final int current;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final done = index < current;
    final active = index == current;
    final color = done || active ? p.brand : p.inkMuted;
    final fill = done
        ? p.brand
        : active
            ? p.brandContainer
            : p.surfaceSoft;

    return Column(
      children: [
        AnimatedContainer(
          duration: AppDurations.fast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? p.brand : p.hairline,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active ? AppElevation.lifted : null,
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 18,
            color: done ? p.inkOnBrand : color,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KitTypography.caption.copyWith(
              color: active ? p.ink : p.inkMuted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// Solid form card wrapper.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PrimeContentCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

/// Review panel before final register submit.
class AuthRegisterSummary extends StatelessWidget {
  const AuthRegisterSummary({
    super.key,
    required this.name,
    required this.nickname,
    required this.email,
  });

  final String name;
  final String nickname;
  final String email;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _SummaryRow(label: 'Имя', value: name),
            Divider(height: 16, color: p.hairline),
            _SummaryRow(label: 'Никнейм', value: '@$nickname'),
            Divider(height: 16, color: p.hairline),
            _SummaryRow(label: 'Email', value: email),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: KitTypography.caption.copyWith(color: p.inkMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: SelectableText(
            value,
            style: KitTypography.cardTitle.copyWith(color: p.ink, fontSize: 15),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Nickname availability hint styling.
class AuthFieldHint extends StatelessWidget {
  const AuthFieldHint({super.key, required this.text, required this.tone});

  final String text;
  final AuthFieldHintTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final color = switch (tone) {
      AuthFieldHintTone.neutral => p.inkMuted,
      AuthFieldHintTone.positive => p.mint,
      AuthFieldHintTone.negative => p.coral,
      AuthFieldHintTone.loading => p.brandSoft,
    };
    final icon = switch (tone) {
      AuthFieldHintTone.neutral => Icons.info_outline_rounded,
      AuthFieldHintTone.positive => Icons.check_circle_outline_rounded,
      AuthFieldHintTone.negative => Icons.error_outline_rounded,
      AuthFieldHintTone.loading => Icons.hourglass_empty_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              text,
              style: KitTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

enum AuthFieldHintTone { neutral, positive, negative, loading }

/// Bottom text action for auth flows.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Center(
      child: TextButton(
        onPressed: () {
          AppHaptics.selection();
          onPressed();
        },
        child: Text(
          label,
          style: KitTypography.body.copyWith(
            color: p.brandSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
