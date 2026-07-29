import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// Standard screen shell with SafeArea and an optional top banner slot.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.banner,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.backgroundColor,
    this.safeTop = true,
    this.safeBottom = true,
    this.padding,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? banner;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final Color? backgroundColor;
  final bool safeTop;
  final bool safeBottom;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (banner != null) banner!,
        Expanded(
          child: padding == null
              ? body
              : Padding(padding: padding!, child: body),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: safeTop,
        bottom: safeBottom,
        child: content,
      ),
    );
  }
}
