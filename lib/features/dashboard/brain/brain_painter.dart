import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/dash_theme.dart';
import 'brain_model.dart';

/// Renders the brain: slow Y rotation + fixed X tilt, perspective projection,
/// depth-sorted so far particles read dimmer/smaller. Everything static is
/// precomputed; the hot loop only does transform math and reuses buffers.
class BrainPainter extends CustomPainter {
  BrainPainter(this.model, this.time) : super(repaint: time) {
    final n = model.nodes.length;
    _sx = Float32List(n);
    _sy = Float32List(n);
    _rad = Float32List(n);
    _near = Float32List(n);
    _order = List<int>.generate(n, (i) => i);
  }

  final BrainModel model;
  final ValueListenable<double> time;

  late final Float32List _sx, _sy, _rad, _near;
  late final List<int> _order;

  // One Paint per stroke class; colour is mutated per draw, never reallocated.
  final _edge = Paint()..strokeWidth = 1;
  final _node = Paint()..style = PaintingStyle.fill;
  final _glow = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  Shader? _bg;
  Size _bgSize = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final cx = w / 2, cy = h / 2, R = min(w, h) * 0.54;

    // Subtle radial accent tint (shader cached by size — no per-frame alloc).
    if (_bg == null || size != _bgSize) {
      _bgSize = size;
      _bg = RadialGradient(
        colors: [DashColors.accent.withValues(alpha: 0.06), const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R * 1.6));
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = _bg);

    final t = time.value;
    final angleY = t * (2 * pi / 60); // ~1 rev / 60s
    const tilt = 0.35;
    final cosY = cos(angleY), sinY = sin(angleY), cosX = cos(tilt), sinX = sin(tilt);
    const camZ = 3.2, focal = 2.4;
    final nodes = model.nodes;

    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final x1 = n.x * cosY + n.z * sinY;
      final z1 = -n.x * sinY + n.z * cosY;
      final y2 = n.y * cosX - z1 * sinX;
      final z2 = n.y * sinX + z1 * cosX;
      final s = focal / (camZ - z2);
      _sx[i] = cx + x1 * s * R;
      _sy[i] = cy - y2 * s * R;
      final near = ((z2 + 1.2) / 2.4).clamp(0.0, 1.0); // 1 = closest to camera
      _near[i] = near;
      var rad = n.size * (0.5 + 0.6 * near);
      if (n.pulses) rad *= 0.85 + 0.3 * sin(t * 2 + n.phase);
      _rad[i] = rad;
    }

    // Edges first, opacity from the nearer endpoint.
    for (final (a, b) in model.edges) {
      final near = _near[a] > _near[b] ? _near[a] : _near[b];
      _edge.color = DashColors.accent.withValues(alpha: 0.08 + 0.12 * near);
      canvas.drawLine(Offset(_sx[a], _sy[a]), Offset(_sx[b], _sy[b]), _edge);
    }

    // Nodes far→near so near ones layer on top.
    _order.sort((a, b) => _near[a].compareTo(_near[b]));
    for (final i in _order) {
      final near = _near[i];
      var alpha = 0.25 + 0.65 * near;
      if (nodes[i].pulses) alpha *= 0.7 + 0.3 * sin(t * 2 + nodes[i].phase);
      final c = Offset(_sx[i], _sy[i]);
      if (model.glow.contains(i) && near > 0.4) {
        _glow.color = DashColors.accent.withValues(alpha: (alpha * 0.5).clamp(0.0, 1.0));
        canvas.drawCircle(c, _rad[i] * 1.8, _glow);
      }
      _node.color = DashColors.accent.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(c, _rad[i], _node);
    }
  }

  @override
  bool shouldRepaint(BrainPainter old) => old.model != model;
}
