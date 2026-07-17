import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'brain_model.dart';
import 'brain_painter.dart';

/// Ticker-driven brain hero. Isolated in a RepaintBoundary and paused whenever
/// the window loses focus (lifecycle != resumed) or the widget leaves the tree.
class BrainView extends StatefulWidget {
  const BrainView({super.key});

  @override
  State<BrainView> createState() => _BrainViewState();
}

class _BrainViewState extends State<BrainView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final BrainModel _model = BrainModel.generate();
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed && !_ticker.isActive) {
      _ticker.start();
    } else if (!resumed && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: BrainPainter(_model, _time), size: Size.infinite),
      );
}
