import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';
import 'dash_icon.dart';

/// Centered icon + message for placeholder / empty screens.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.subtitle});

  final String icon;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DashIcon(icon, size: 40, color: DashColors.text2),
          const SizedBox(height: DashSpace.x3),
          Text(message, style: DashType.body.copyWith(color: DashColors.text1)),
          if (subtitle != null) ...[
            const SizedBox(height: DashSpace.x1),
            Text(subtitle!, style: DashType.label),
          ],
        ],
      ),
    );
  }
}
