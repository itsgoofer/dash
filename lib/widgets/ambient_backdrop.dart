import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/dash_theme.dart';

/// Ambient scene behind section content: a faint 1px grid, two or three huge
/// accent glow blobs drifting on slow sine paths, and a scanline sweeping down
/// every ~20s. Atmosphere, not decoration — everything sits at 2–5% opacity.
///
/// Single ticker-driven CustomPaint in a RepaintBoundary; the ticker pauses
/// whenever the window loses focus (same pattern as BrainView).
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({super.key});

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
        child: CustomPaint(painter: _AmbientPainter(_time), size: Size.infinite),
      );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;

  static const _gridStep = 48.0;
  static const _scanPeriod = 20.0; // seconds per sweep

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    _grid(canvas, size);
    _blobs(canvas, size, t);
    _scanline(canvas, size, t);
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..strokeWidth = 1;
    for (var x = _gridStep; x < size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _gridStep; y < size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _blobs(Canvas canvas, Size size, double t) {
    // (base x, base y, radius fraction, drift phase, speed, alpha)
    const specs = [
      (0.18, 0.25, 0.42, 0.0, 0.045, 0.045),
      (0.85, 0.70, 0.50, 2.1, 0.032, 0.035),
      (0.55, 0.05, 0.34, 4.4, 0.058, 0.030),
    ];
    final accent = DashColors.accent;
    for (final (fx, fy, fr, phase, speed, alpha) in specs) {
      final center = Offset(
        size.width * (fx + 0.06 * math.sin(t * speed * math.pi * 2 + phase)),
        size.height * (fy + 0.08 * math.cos(t * speed * math.pi * 2 * 0.8 + phase * 1.7)),
      );
      final radius = size.width * fr;
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          accent.withValues(alpha: alpha),
          accent.withValues(alpha: 0),
        ]);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _scanline(Canvas canvas, Size size, double t) {
    const band = 90.0;
    final phase = (t % _scanPeriod) / _scanPeriod;
    final y = phase * (size.height + band * 2) - band;
    final rect = Rect.fromLTWH(0, y - band / 2, size.width, band);
    final paint = Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomLeft, [
        Colors.white.withValues(alpha: 0),
        DashColors.accent.withValues(alpha: 0.02),
        Colors.white.withValues(alpha: 0),
      ], const [0, 0.5, 1]);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => false; // repaint listenable drives frames
}
