import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';

const _series = [
  (key: 'rating', label: 'Rating', color: DashColors.accent),
  (key: 'energy', label: 'Energy', color: DashColors.accent2),
  (key: 'productivity', label: 'Focus', color: DashColors.success),
];

int? _valueFor(DayMetrics d, String key) =>
    switch (key) { 'rating' => d.rating, 'energy' => d.energy, _ => d.productivity };

/// 14-day line chart of rating / energy / productivity, glow-styled per the
/// design system. Missing days are gaps, not zeros.
class MetricCharts extends ConsumerWidget {
  const MetricCharts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final empty = metrics.every((d) => d.isEmpty);
    return LayoutBuilder(
      builder: (context, c) {
        if (empty) return const _EmptyChart();
        const labelStrip = 76.0, bottomAxis = 22.0, topPad = 6.0;
        final plotH = c.maxHeight - bottomAxis - topPad;
        const minGap = 16.0;
        final labels = [
          for (final s in _series)
            if (_lastValue(metrics, s.key) case final v?)
              (s.label, s.color, (topPad + (1 - v / 10) * plotH - 8).clamp(0.0, c.maxHeight - minGap)),
        ]..sort((a, b) => a.$3.compareTo(b.$3));
        for (var i = 1; i < labels.length; i++) {
          if (labels[i].$3 - labels[i - 1].$3 < minGap) {
            labels[i] = (labels[i].$1, labels[i].$2, labels[i - 1].$3 + minGap);
          }
        }
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: labelStrip),
              child: LineChart(_data(metrics), duration: DashMotion.chart, curve: DashMotion.curve),
            ),
            for (final (label, color, top) in labels)
              Positioned(
                right: 0,
                width: labelStrip,
                top: top,
                child: Padding(
                  padding: const EdgeInsets.only(left: DashSpace.x2),
                  child: Text(label, style: DashType.small.copyWith(color: color, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        );
      },
    );
  }

  double? _lastValue(List<DayMetrics> m, String key) {
    for (var i = m.length - 1; i >= 0; i--) {
      final v = _valueFor(m[i], key);
      if (v != null) return v.toDouble();
    }
    return null;
  }

  LineChartData _data(List<DayMetrics> m) {
    List<FlSpot> spots(String key) => [
          for (var i = 0; i < m.length; i++)
            if (_valueFor(m[i], key) case final v?) FlSpot(i.toDouble(), v.toDouble()) else FlSpot.nullSpot,
        ];

    LineChartBarData underlay(String key, Color color) => LineChartBarData(
          spots: spots(key),
          isCurved: true,
          preventCurveOverShooting: true,
          color: color.withValues(alpha: 0.25),
          barWidth: 6,
          dotData: const FlDotData(show: false),
        );

    LineChartBarData line(String key, Color color) => LineChartBarData(
          spots: spots(key),
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
            ),
          ),
        );

    return LineChartData(
      minX: 0,
      maxX: (m.length - 1).toDouble(),
      minY: 0,
      maxY: 10,
      // Soft glow underlays first, crisp lines on top.
      lineBarsData: [
        for (final s in _series) underlay(s.key, s.color),
        for (final s in _series) line(s.key, s.color),
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (_) => FlLine(color: DashColors.glassBorder.withValues(alpha: 0.5), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.round();
              if (i < 0 || i >= m.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: DashSpace.x1),
                child: Text('${m[i].date.day}', style: DashType.small.copyWith(color: DashColors.text2)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => DashColors.bg1,
          tooltipBorder: BorderSide(color: DashColors.glassBorder),
          tooltipBorderRadius: DashRadius.br,
          getTooltipItems: (spots) => spots.map((s) {
            if (s.bar.barWidth != 2) return null; // skip glow underlays
            final label = _series.firstWhere((e) => e.color == s.bar.color).label;
            return LineTooltipItem('$label  ${s.y.toInt()}',
                DashType.small.copyWith(color: s.bar.color, fontWeight: FontWeight.w600));
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Nothing logged yet — today's a blank page.",
        style: DashType.body.copyWith(color: DashColors.text1),
        textAlign: TextAlign.center,
      ),
    );
  }
}
