import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Translucent panel with blur, subtle border and optional accent glow.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DashSpace.x3),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DashRadius.br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: DashColors.glassFill,
            borderRadius: DashRadius.br,
            border: Border.all(color: DashColors.glassBorder),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: DashColors.accent.withValues(alpha: 0.18),
                      blurRadius: 24,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
