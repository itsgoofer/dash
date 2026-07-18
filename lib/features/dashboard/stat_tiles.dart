import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/hud_frame.dart';

/// Dashboard stats as compact HUD chips (icon + Rajdhani numeral + tiny
/// uppercase label), fed by [dashboardStatsProvider].
class HudStatChips extends ConsumerWidget {
  const HudStatChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dashboardStatsProvider);
    final openTasks = ref.watch(dashboardOpenTasksProvider);
    final chips = [
      (icon: 'calendar_today', label: 'DAY STREAK', value: s.streak),
      (icon: 'book_2', label: 'ENTRIES / WK', value: s.entriesThisWeek),
      (icon: 'folder_open', label: 'TOTAL NOTES', value: s.totalNotes),
      (icon: 'deployed_code', label: 'PROJECTS', value: s.activeProjects),
      (icon: 'check', label: 'OPEN TASKS', value: openTasks),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: DashSpace.x2,
        runSpacing: DashSpace.x2,
        children: [
          for (final c in chips) _Chip(icon: c.icon, label: c.label, value: c.value),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: HudFrame(
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3, vertical: DashSpace.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                DashIcon(icon, size: 13, color: DashColors.accent.withValues(alpha: 0.8)),
                const Spacer(),
                Text(
                  value == 0 ? '—' : '$value',
                  style: DashType.clockSmall.copyWith(
                    fontSize: 26,
                    color: value == 0 ? DashColors.text2 : DashColors.text0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DashSpace.x1),
            Text(label, style: DashType.hudLabel.copyWith(fontSize: 9, letterSpacing: 1.8)),
          ],
        ),
      ),
    );
  }
}
