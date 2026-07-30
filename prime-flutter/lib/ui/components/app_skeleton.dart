import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/shapes/prime_squircle.dart';
import '../../design/tokens.dart';
import '../kit/presentation/profile_editorial_widgets.dart';
import '../kit/tokens/kit_layout.dart';

/// Lightweight shimmer-style placeholder for partial loading states.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.sm);
    final box = Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface.withValues(alpha: 0.72),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    );
    return PrimeShimmer(child: box);
  }
}

/// Habit-grid style skeleton used while skills load.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        KitLayout.scrollBottomFor(context),
      ),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (_, __) => const AppCardSkeleton(),
        ),
      ],
    );
  }
}

class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimeSquircleClip(
      radius: AppRadius.lg,
      child: PrimeShimmer(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: AppColors.surface.withValues(alpha: 0.8),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSkeleton(height: 40, width: 40),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(height: 18, width: 120),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(height: 12),
              SizedBox(height: AppSpacing.xxs),
              AppSkeleton(height: 12, width: 160),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 12, width: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class AppChatListSkeleton extends StatelessWidget {
  const AppChatListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const Row(
        children: [
          AppSkeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(height: 14, width: 140),
                SizedBox(height: AppSpacing.xs),
                AppSkeleton(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppProfileSkeleton extends StatelessWidget {
  const AppProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: AppSkeleton(
            height: 680,
            borderRadius: BorderRadius.all(
              Radius.circular(ProfileHeroCard.cardRadius),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppSkeleton(
                height: 160,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(
                height: 120,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppGroupSearchSkeleton extends StatelessWidget {
  const AppGroupSearchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(height: 22, width: 180),
          const SizedBox(height: AppSpacing.sm),
          const AppSkeleton(height: 14, width: 240),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs),
                  child: AppSkeleton(
                    width: 40,
                    height: 40,
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.pill)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSkeleton(height: 52),
        ],
      ),
    );
  }
}
