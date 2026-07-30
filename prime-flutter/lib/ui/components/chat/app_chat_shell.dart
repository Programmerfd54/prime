import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../ui/kit/presentation/profile_surfaces.dart';

/// V5 unified chat layout — team + direct share one shell, canvas, composer slot.
class AppChatShell extends StatelessWidget {
  const AppChatShell({
    super.key,
    this.appBar,
    this.banner,
    this.header,
    required this.messageArea,
    required this.composer,
    this.showScrollToBottom = false,
    this.onScrollToBottom,
    this.scrollBottomOffset = 96,
    this.scrollHeroTag = 'chat_scroll_bottom',
  });

  final PreferredSizeWidget? appBar;
  final Widget? banner;
  final Widget? header;
  final Widget messageArea;
  final Widget composer;
  final bool showScrollToBottom;
  final VoidCallback? onScrollToBottom;
  final double scrollBottomOffset;
  final String scrollHeroTag;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return ColoredBox(
      color: ProfileSurfaces.canvas,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: appBar,
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (banner != null) banner!,
                if (header != null) header!,
                Expanded(child: messageArea),
                composer,
              ],
            ),
            if (showScrollToBottom && onScrollToBottom != null)
              Positioned(
                right: AppSpacing.md,
                bottom: scrollBottomOffset,
                child: FloatingActionButton.small(
                  heroTag: scrollHeroTag,
                  backgroundColor: p.brandContainer,
                  foregroundColor: p.brandSoft,
                  onPressed: onScrollToBottom,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opaque strip for cycle / day status above messages (group chat).
class AppChatHeaderStrip extends StatelessWidget {
  const AppChatHeaderStrip({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final body = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}
