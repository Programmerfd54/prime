import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import 'profile_editorial_widgets.dart';
import 'profile_icons.dart';
import 'profile_typography.dart';

/// High-contrast context menu for public participant profiles (TZ §27).
abstract final class ProfileContextMenu {
  static const _desktopBreakpoint = 600.0;
  static const _menuWidth = 248.0;

  static Future<void> show({
    required BuildContext context,
    required String nickname,
    BuildContext? anchorContext,
    VoidCallback? onCopyNickname,
    VoidCallback? onInvite,
    VoidCallback? onBlock,
    VoidCallback? onReport,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= _desktopBreakpoint && anchorContext != null) {
      return _showAnchored(
        context: context,
        anchorContext: anchorContext,
        nickname: nickname,
        onCopyNickname: onCopyNickname,
        onInvite: onInvite,
        onBlock: onBlock,
        onReport: onReport,
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _ProfileContextSheet(
        nickname: nickname,
        onCopyNickname: onCopyNickname,
        onInvite: onInvite,
        onBlock: onBlock,
        onReport: onReport,
      ),
    );
  }

  static Future<void> _showAnchored({
    required BuildContext context,
    required BuildContext anchorContext,
    required String nickname,
    VoidCallback? onCopyNickname,
    VoidCallback? onInvite,
    VoidCallback? onBlock,
    VoidCallback? onReport,
  }) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ProfileContextSheet(
          nickname: nickname,
          onCopyNickname: onCopyNickname,
          onInvite: onInvite,
          onBlock: onBlock,
          onReport: onReport,
        ),
      );
    }

    final offset = box.localToGlobal(Offset.zero);
    final anchor = offset & box.size;
    final screen = MediaQuery.sizeOf(context);

    final left = (anchor.right - _menuWidth).clamp(8.0, screen.width - _menuWidth - 8);
    final top = (anchor.top - 8).clamp(8.0, screen.height - 280);

    return showMenu<void>(
      context: context,
      color: ProfilePalette.charcoal,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
        ),
      ),
      position: RelativeRect.fromLTRB(
        left,
        top,
        left + _menuWidth,
        top + 1,
      ),
      items: _menuEntries(
        nickname: nickname,
        onCopyNickname: onCopyNickname,
        onInvite: onInvite,
        onBlock: onBlock,
        onReport: onReport,
        pop: () => Navigator.pop(context),
      ),
    );
  }

  static List<PopupMenuEntry<void>> _menuEntries({
    required String nickname,
    required VoidCallback pop,
    VoidCallback? onCopyNickname,
    VoidCallback? onInvite,
    VoidCallback? onBlock,
    VoidCallback? onReport,
  }) {
    final items = <PopupMenuEntry<void>>[];
    if (nickname.isNotEmpty) {
      items.add(
        _PopupRow(
          icon: ProfileIcons.copy,
          label: 'Скопировать @$nickname',
          onTap: () {
            pop();
            Clipboard.setData(ClipboardData(text: '@$nickname'));
            onCopyNickname?.call();
          },
        ),
      );
    }
    if (onInvite != null) {
      items.add(
        _PopupRow(
          icon: ProfileIcons.invite,
          label: 'Пригласить',
          onTap: () {
            pop();
            onInvite();
          },
        ),
      );
    }
    if (onBlock != null) {
      items.add(
        _PopupRow(
          icon: ProfileIcons.block,
          label: 'Скрыть',
          onTap: () {
            pop();
            onBlock();
          },
        ),
      );
    }
    if (onReport != null) {
      items.add(const PopupMenuDivider());
      items.add(
        _PopupRow(
          icon: ProfileIcons.flag,
          label: 'Пожаловаться',
          destructive: true,
          onTap: () {
            pop();
            onReport();
          },
        ),
      );
    }
    return items;
  }
}

class _PopupRow extends PopupMenuEntry<void> {
  const _PopupRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  double get height => 50;

  @override
  bool represents(void value) => false;

  @override
  State<_PopupRow> createState() => _PopupRowState();
}

class _PopupRowState extends State<_PopupRow> {
  @override
  Widget build(BuildContext context) {
    final color = widget.destructive
        ? const Color(0xFFFF6B6B)
        : ProfilePalette.offWhite.withValues(alpha: 0.92);

    return InkWell(
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              ProfileIcon(widget.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: ProfileTypography.cta.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContextSheet extends StatelessWidget {
  const _ProfileContextSheet({
    required this.nickname,
    this.onCopyNickname,
    this.onInvite,
    this.onBlock,
    this.onReport,
  });

  final String nickname;
  final VoidCallback? onCopyNickname;
  final VoidCallback? onInvite;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ProfilePalette.charcoal,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ProfilePalette.coolGrey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (nickname.isNotEmpty)
              _MenuRow(
                icon: ProfileIcons.copy,
                label: 'Скопировать @$nickname',
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: '@$nickname'));
                  onCopyNickname?.call();
                },
              ),
            if (onInvite != null)
              _MenuRow(
                icon: ProfileIcons.invite,
                label: 'Пригласить',
                onTap: () {
                  Navigator.pop(context);
                  onInvite!();
                },
              ),
            if (onBlock != null)
              _MenuRow(
                icon: ProfileIcons.block,
                label: 'Скрыть',
                onTap: () {
                  Navigator.pop(context);
                  onBlock!();
                },
              ),
            if (onReport != null) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
              ),
              _MenuRow(
                icon: ProfileIcons.flag,
                label: 'Пожаловаться',
                destructive: true,
                onTap: () {
                  Navigator.pop(context);
                  onReport!();
                },
              ),
            ],
            SizedBox(height: AppSpacing.sm + bottom * 0.25),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF6B6B)
        : ProfilePalette.offWhite.withValues(alpha: 0.92);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                ProfileIcon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: ProfileTypography.cta.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
