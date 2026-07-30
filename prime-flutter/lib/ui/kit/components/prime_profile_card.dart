import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../design/tokens.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../tokens/kit_typography.dart';

/// Profile hero block — cover strip, avatar, name, clamped bio.
class PrimeProfileCard extends StatefulWidget {
  const PrimeProfileCard({
    super.key,
    required this.name,
    this.photoUrl,
    this.coverColor,
    this.bio,
    this.actions,
    this.metrics = const [],
    this.onAvatarTap,
  });

  final String name;
  final String? photoUrl;
  final Color? coverColor;
  final String? bio;
  final List<Widget>? actions;
  final List<Widget> metrics;
  final VoidCallback? onAvatarTap;

  @override
  State<PrimeProfileCard> createState() => _PrimeProfileCardState();
}

class _PrimeProfileCardState extends State<PrimeProfileCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final bio = widget.bio?.trim() ?? '';
    final sanitized = bio.replaceAll(RegExp(r'\s+'), ' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.coverColor ?? p.brand.withValues(alpha: 0.45),
                  p.surfaceElevated,
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: widget.onAvatarTap,
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: p.surfaceElevated,
                        backgroundImage: () {
                          final url = absolutePhotoUrl(widget.photoUrl);
                          return url != null ? NetworkImage(url) : null;
                        }(),
                        child: widget.photoUrl == null
                            ? Text(
                                widget.name.isNotEmpty
                                    ? widget.name[0].toUpperCase()
                                    : '?',
                                style: KitTypography.sectionTitle,
                              )
                            : null,
                      ),
                    ),
                    const Spacer(),
                    if (widget.actions != null) ...widget.actions!,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.name, style: KitTypography.pageTitle.copyWith(fontSize: 26)),
                if (sanitized.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: sanitized.length > 120 ? () => setState(() => _expanded = !_expanded) : null,
                    child: Text(
                      sanitized,
                      style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (widget.metrics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      for (var i = 0; i < widget.metrics.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(child: widget.metrics[i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
