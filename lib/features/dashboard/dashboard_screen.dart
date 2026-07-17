import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/dash_theme.dart';
import '../../widgets/glass_panel.dart';
import 'brain/brain_view.dart';
import 'metric_charts.dart';
import 'stat_tiles.dart';

final _dateFmt = DateFormat('EEEE, MMMM d');

/// The Jarvis home screen: greeting, brain hero, 14-day chart, stat tiles.
/// Entrance animates once (staggered fade + rise).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final brainH = (c.maxHeight * 0.52).clamp(360.0, 640.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Rise(index: 0, child: _Greeting()),
              const SizedBox(height: DashSpace.x4),
              _Rise(
                index: 1,
                child: SizedBox(
                  height: brainH,
                  child: const _Panel(title: 'NEURAL INDEX', child: BrainView()),
                ),
              ),
              const SizedBox(height: DashSpace.x3),
              const _Rise(
                index: 2,
                child: SizedBox(
                  height: 220,
                  child: _Panel(title: 'LAST 14 DAYS', child: MetricCharts()),
                ),
              ),
              const SizedBox(height: DashSpace.x3),
              const _Rise(index: 3, child: StatTiles()),
            ],
          ),
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting.', style: DashType.display),
        const SizedBox(height: DashSpace.x1),
        Text('Systems online.  ·  ${_dateFmt.format(DateTime.now())}',
            style: DashType.small.copyWith(color: DashColors.text1)),
      ],
    );
  }
}

/// A titled glass panel; the small caption is decorative flavour.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.title});
  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(DashSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: DashType.small.copyWith(color: DashColors.text2, letterSpacing: 1.5)),
          const SizedBox(height: DashSpace.x3),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Staggered fade + rise, played once on first mount (30ms/item per motion spec).
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
    Future.delayed(DashMotion.stagger * widget.index, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: DashMotion.duration,
      curve: DashMotion.curve,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: DashMotion.duration,
        curve: DashMotion.curve,
        child: widget.child,
      ),
    );
  }
}
