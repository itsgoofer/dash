import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/glass_panel.dart';

/// Row of four glass stat tiles fed by [dashboardStatsProvider].
class StatTiles extends ConsumerWidget {
  const StatTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dashboardStatsProvider);
    final tiles = [
      (icon: 'calendar_today', label: 'Day streak', value: s.streak),
      (icon: 'book_2', label: 'Entries this week', value: s.entriesThisWeek),
      (icon: 'folder_open', label: 'Total notes', value: s.totalNotes),
      (icon: 'deployed_code', label: 'Active projects', value: s.activeProjects),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: DashSpace.x3),
          Expanded(child: _Tile(icon: tiles[i].icon, label: tiles[i].label, value: tiles[i].value)),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashIcon(icon, size: 18, color: DashColors.text2),
          const SizedBox(height: DashSpace.x3),
          Text(
            value == 0 ? '—' : '$value',
            style: DashType.mono.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: value == 0 ? DashColors.text2 : DashColors.text0,
            ),
          ),
          const SizedBox(height: DashSpace.x1),
          Text(label, style: DashType.small.copyWith(color: DashColors.text1)),
        ],
      ),
    );
  }
}
