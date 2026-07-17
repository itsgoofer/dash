import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Text with a soft accent glow, for wordmarks and highlighted numbers.
class GlowText extends StatelessWidget {
  const GlowText(
    this.text, {
    super.key,
    this.style,
    this.color = DashColors.accent,
    this.blurRadius = 16,
  });

  final String text;
  final TextStyle? style;
  final Color color;
  final double blurRadius;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? DashType.title).copyWith(
        color: color,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.8), blurRadius: blurRadius),
          Shadow(color: color.withValues(alpha: 0.4), blurRadius: blurRadius * 2),
        ],
      ),
    );
  }
}
