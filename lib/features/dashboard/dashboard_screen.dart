import 'package:flutter/material.dart';

import '../../theme/dash_theme.dart';
import '../../widgets/hud_frame.dart';
import 'brain/brain_view.dart';
import 'hero_header.dart';
import 'metric_charts.dart';
import 'telemetry_ticker.dart';

/// The Jarvis home screen: hero header (clock / greeting / weather / HUD
/// chips), the neural brain centerpiece with a telemetry ticker overlay, and
/// the 14-day biometrics chart. Entrance animates once (staggered fade + rise).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Brain gets the majority of the viewport; small windows just scroll.
        final brainH = (c.maxHeight * 0.58).clamp(420.0, 780.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Rise(index: 0, child: HeroHeader()),
              const SizedBox(height: DashSpace.x4),
              _Rise(
                index: 1,
                child: SizedBox(
                  height: brainH,
                  child: const HudFrame(
                    title: 'NEURAL CORTEX — VAULT MAP',
                    child: Stack(
                      children: [
                        Positioned.fill(child: BrainView()),
                        Positioned(left: 2, bottom: 2, child: TelemetryTicker()),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DashSpace.x3),
              const _Rise(
                index: 2,
                child: SizedBox(
                  height: 216,
                  child: HudFrame(title: 'BIOMETRICS — LAST 14 DAYS', child: MetricCharts()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Staggered fade + 8px rise, played once on first mount (40ms apart, 200ms).
class _Rise extends StatefulWidget {
  const _Rise({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: DashMotion.screen,
      curve: DashMotion.curve,
      child: AnimatedContainer(
        duration: DashMotion.screen,
        curve: DashMotion.curve,
        transform: Matrix4.translationValues(0, _shown ? 0 : 8, 0),
        child: widget.child,
      ),
    );
  }
}
