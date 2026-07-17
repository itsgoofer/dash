import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Status/select value chip: radius 4, tinted 15% of [color].
class DashChip extends StatelessWidget {
  const DashChip(this.label, {super.key, this.color = DashColors.text1});

  final String label;
  final Color color;

  static const _palette = [
    DashColors.accent,
    DashColors.accent2,
    DashColors.success,
    DashColors.warning,
  ];

  /// Stable color for a select/multiselect option (hash of its name).
  static Color optionColor(String option) =>
      _palette[option.toLowerCase().codeUnits.fold(0, (a, c) => a + c) % _palette.length];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: DashRadius.br),
        child: Text(label, style: DashType.small.copyWith(color: color, fontWeight: FontWeight.w500)),
      );
}
