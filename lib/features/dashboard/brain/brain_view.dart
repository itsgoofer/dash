import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../../../theme/dash_theme.dart';
import 'brain_model.dart';
import 'brain_painter.dart';

/// Live node/edge counts for the corner readouts and telemetry ticker.
final brainStats = ValueNotifier<({int nodes, int edges})>((nodes: 0, edges: 0));

/// Ticker-driven brain hero. Node count tracks the real vault size (bucketed so
/// the model isn't churned), drag-to-rotate with momentum, hover flare, pulse
/// signals. Isolated in a RepaintBoundary and paused whenever the window loses
/// focus (lifecycle != resumed) or the widget leaves the tree.
class BrainView extends ConsumerStatefulWidget {
  const BrainView({super.key});

  @override
  ConsumerState<BrainView> createState() => _BrainViewState();
}

class _BrainViewState extends ConsumerState<BrainView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  BrainModel? _model;
  int _bucket = -1;
  final _time = ValueNotifier<double>(0);
  final _input = BrainInput();
  final _rotDeg = ValueNotifier<int>(0);
  final _rnd = Random();
  late final Ticker _ticker;
  Duration _prev = Duration.zero;
  double _nextPulse = 1.0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration e) {
    var dt = (e - _prev).inMicroseconds / 1e6;
    _prev = e;
    if (dt < 0 || dt > 0.1) dt = 0; // ticker restart after blur — no time jump
    final t = _time.value + dt;

    // Fling momentum decays back into the slow auto-rotation.
    _input.userAngle += _input.vel * dt;
    if (_input.vel != 0) {
      _input.vel *= pow(0.08, dt);
      if (_input.vel.abs() < 0.02) _input.vel = 0;
    }
    if (!_dragging) _input.tiltOffset *= pow(0.25, dt).toDouble();
    _input.angleY = t * (2 * pi / 60) + _input.userAngle;

    // Stochastic pulse spawn (~every 0.6–1s, 2–4 concurrent).
    final edges = _model?.edges.length ?? 0;
    if (edges > 0 && t >= _nextPulse) {
      if (_input.pulses.length < 4) {
        _input.pulses.add(Pulse(_rnd.nextInt(edges), t, 0.8 + _rnd.nextDouble() * 0.9, _rnd.nextBool()));
      }
      _nextPulse = t + 0.6 + _rnd.nextDouble() * 0.4;
    }
    _input.pulses.removeWhere((p) => (t - p.t0) * p.speed > 1.3);

    final deg = (((_input.angleY * 180 / pi) % 360) + 360).round() % 360;
    if (deg != _rotDeg.value) _rotDeg.value = deg;
    _time.value = t;
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
    _rotDeg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Node count from the real vault, bucketed in steps of 25 to avoid churn.
    final total = ref.watch(dashboardStatsProvider.select((s) => s.totalNotes));
    final bucket = (((total * 3).clamp(180, 600) / 25).round() * 25).clamp(180, 600);
    if (bucket != _bucket) {
      _bucket = bucket;
      _model = BrainModel.generate(nodeCount: bucket);
      _input.pulses.clear(); // old edge indices are invalid
      final stats = (nodes: _model!.nodes.length, edges: _model!.edges.length);
      WidgetsBinding.instance.addPostFrameCallback((_) => brainStats.value = stats);
    }

    return MouseRegion(
      onHover: (e) => _input.hover = e.localPosition,
      onExit: (_) => _input.hover = null,
      child: GestureDetector(
        onPanStart: (_) {
          _dragging = true;
          _input.vel = 0;
        },
        onPanUpdate: (d) {
          _input.userAngle += d.delta.dx * 0.008;
          _input.tiltOffset = (_input.tiltOffset - d.delta.dy * 0.004).clamp(-0.5, 0.5);
        },
        onPanEnd: (d) {
          _dragging = false;
          _input.vel = (d.velocity.pixelsPerSecond.dx * 0.008).clamp(-8.0, 8.0);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: RepaintBoundary(
                  child: CustomPaint(painter: BrainPainter(_model!, _time, _input), size: Size.infinite),
                ),
              ),
            ),
            Positioned(
              left: 2,
              top: 2,
              child: ValueListenableBuilder(
                valueListenable: brainStats,
                builder: (context, s, child) =>
                    Text('NODES ${s.nodes} · EDGES ${s.edges}', style: DashType.ticker),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: RepaintBoundary(
                child: ValueListenableBuilder(
                  valueListenable: _rotDeg,
                  builder: (context, d, child) =>
                      Text('ROT ${d.toString().padLeft(3, '0')}°', style: DashType.ticker),
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Text('DRAG TO ROTATE', style: DashType.ticker.copyWith(color: DashColors.text2)),
            ),
          ],
        ),
      ),
    );
  }
}
