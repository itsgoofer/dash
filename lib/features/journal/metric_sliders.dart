import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/glass_panel.dart';

/// The five 1–10 day metrics as glowing discrete sliders, in a GlassPanel.
class MetricSliders extends ConsumerWidget {
  const MetricSliders({super.key, required this.date, required this.metrics});

  final DateTime date;
  final Map<String, int> metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(journalNoteProvider(date).notifier);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: DashSpace.x4, vertical: DashSpace.x3),
      child: Column(
        children: [
          for (final key in journalMetrics)
            _MetricRow(
              label: key[0].toUpperCase() + key.substring(1),
              value: metrics[key],
              onChanged: (v) => notifier.setMetric(key, v),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final set = value != null;
    return SizedBox(
      height: DashSize.control,
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: DashType.label)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                inactiveTrackColor: set ? DashColors.glassBorder : DashColors.glassBorder.withValues(alpha: 0.5),
                thumbColor: set ? Colors.white : DashColors.text2,
              ),
              child: Slider(
                value: (value ?? 1).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          const SizedBox(width: DashSpace.x2),
          SizedBox(
            width: 20,
            child: Text(
              set ? '$value' : '—',
              textAlign: TextAlign.right,
              style: DashType.mono.copyWith(color: set ? DashColors.accent : DashColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}
