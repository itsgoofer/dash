import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/dash_theme.dart';
import 'brain_model.dart';

/// A bright signal travelling along edge index [edge]. Spawned stochastically
/// or as part of a cascade ([gen] > 0); on arrival it fires its target node.
class Pulse {
  Pulse(this.edge, this.t0, this.speed, this.reversed, {this.gen = 0});
  final int edge;
  final double t0, speed;
  final bool reversed;
  final int gen;
  bool arrived = false;
}

/// Mutable per-frame interaction state written by BrainView (ticker + gestures)
/// and read by the painter — no painter rebuilds for interaction.
class BrainInput {
  double angleY = 0; // total rotation (auto + user), set each tick
  double tiltOffset = 0; // vertical-drag tilt, eases back to 0
  double userAngle = 0;
  double vel = 0; // momentum after a fling, decays
  Offset? hover;
  final pulses = <Pulse>[];
  Float32List fire = Float32List(0); // per-node last-fired time (cascade flash)
  final storms = <(int node, double t0)>[]; // active shockwave origins
}

/// Renders the brain: rotation + tilt, perspective projection, depth-sorted
/// nodes, orbit rings behind, hover flare and travelling pulses. Everything
/// static is precomputed; the hot loop only does transform math on buffers.
class BrainPainter extends CustomPainter {
  BrainPainter(this.model, this.time, this.input) : super(repaint: time) {
    final n = model.nodes.length;
    _sx = Float32List(n);
    _sy = Float32List(n);
    _rad = Float32List(n);
    _near = Float32List(n);
    _flare = Float32List(n);
    _ex = Float32List(n);
    _order = List<int>.generate(n, (i) => i);
    // Faint dust shell around the brain (fixed seed): parallax depth cue.
    final rnd = Random(11);
    for (var i = 0; i < _kDust; i++) {
      final u = rnd.nextDouble() * 2 - 1, t = rnd.nextDouble() * 2 * pi;
      final r = 1.35 + rnd.nextDouble() * 0.9, s = sqrt(1 - u * u);
      _dust[i * 3] = s * cos(t) * r;
      _dust[i * 3 + 1] = s * sin(t) * r * 0.7;
      _dust[i * 3 + 2] = u * r;
    }
  }

  static const _kDust = 70;
  final _dust = Float32List(_kDust * 3);

  final BrainModel model;
  final ValueListenable<double> time;
  final BrainInput input;

  late final Float32List _sx, _sy, _rad, _near, _flare, _ex;
  late final List<int> _order;

  // One Paint per stroke class; colour is mutated per draw, never reallocated.
  final _edge = Paint()..strokeWidth = 1;
  final _node = Paint()..style = PaintingStyle.fill;
  final _glow = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  Shader? _bg;
  Size _bgSize = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final cx = w / 2, cy = h / 2, R = min(w, h) * 0.52;

    // Subtle radial accent tint (shader cached by size — no per-frame alloc).
    if (_bg == null || size != _bgSize) {
      _bgSize = size;
      _bg = RadialGradient(
        colors: [DashColors.accent.withValues(alpha: 0.06), const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R * 1.6));
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = _bg);

    final t = time.value;
    final angleY = input.angleY;
    final tilt = 0.35 + input.tiltOffset;

    final cosY = cos(angleY), sinY = sin(angleY), cosX = cos(tilt), sinX = sin(tilt);
    const camZ = 3.2, focal = 2.4;
    final nodes = model.nodes;
    final breath = 1 + 0.016 * sin(t * 0.85); // slow whole-brain breathing

    // Dust shell: slower rotation than the brain for parallax depth.
    final cosD = cos(angleY * 0.65), sinD = sin(angleY * 0.65);
    for (var i = 0; i < _kDust; i++) {
      final x = _dust[i * 3], y = _dust[i * 3 + 1], z = _dust[i * 3 + 2];
      final x1 = x * cosD + z * sinD, z1 = -x * sinD + z * cosD;
      final y2 = y * cosX - z1 * sinX, z2 = y * sinX + z1 * cosX;
      final s = focal / (camZ - z2);
      if (s <= 0) continue;
      final near = ((z2 + 1.2) / 2.4).clamp(0.0, 1.0);
      _node.color = DashColors.accent.withValues(alpha: 0.04 + 0.08 * near);
      canvas.drawCircle(Offset(cx + x1 * s * R, cy - y2 * s * R), 0.7 + 0.6 * near, _node);
    }

    _rings(canvas, cx, cy, R, t, tilt);

    final fire = input.fire;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final x1 = n.x * cosY + n.z * sinY;
      final z1 = -n.x * sinY + n.z * cosY;
      final y2 = n.y * cosX - z1 * sinX;
      final z2 = n.y * sinX + z1 * cosX;
      final s = focal / (camZ - z2) * breath;
      _sx[i] = cx + x1 * s * R;
      _sy[i] = cy - y2 * s * R;
      final near = ((z2 + 1.2) / 2.4).clamp(0.0, 1.0); // 1 = closest to camera
      _near[i] = near;

      // Excitement: cascade flash (recent fire) + storm wavefront passing by.
      var ex = 0.0;
      if (i < fire.length) {
        final dt = t - fire[i];
        if (dt >= 0 && dt < 1.6) ex = exp(-dt * 3.2);
      }
      for (final (sn, st0) in input.storms) {
        final c = nodes[sn];
        final age = t - st0;
        final dx = n.x - c.x, dy = n.y - c.y, dz = n.z - c.z;
        final wave = sqrt(dx * dx + dy * dy + dz * dz) - age * 1.35;
        ex += exp(-wave * wave / 0.03) * (1 - age / 2.5).clamp(0.0, 1.0) * 0.9;
      }
      _ex[i] = ex > 1 ? 1 : ex;

      var rad = n.size * (0.5 + 0.6 * near);
      if (n.pulses) rad *= 0.85 + 0.3 * sin(t * 2 + n.phase);
      _rad[i] = rad * (1 + 1.0 * _ex[i]);
    }

    // Cursor proximity flare — smooth gaussian falloff in screen space.
    final hov = input.hover;
    for (var i = 0; i < nodes.length; i++) {
      var f = 0.0;
      if (hov != null) {
        final dx = _sx[i] - hov.dx, dy = _sy[i] - hov.dy;
        final d2 = dx * dx + dy * dy;
        if (d2 < 12000) f = exp(-d2 / 2600);
      }
      _flare[i] = f;
    }

    // Edges first, opacity from the nearer endpoint (+ flare/excitement lift).
    for (final (a, b) in model.edges) {
      final near = _near[a] > _near[b] ? _near[a] : _near[b];
      final f = _flare[a] > _flare[b] ? _flare[a] : _flare[b];
      final e = _ex[a] > _ex[b] ? _ex[a] : _ex[b];
      _edge.color = DashColors.accent.withValues(alpha: (0.08 + 0.12 * near + 0.25 * f + 0.3 * e).clamp(0.0, 1.0));
      canvas.drawLine(Offset(_sx[a], _sy[a]), Offset(_sx[b], _sy[b]), _edge);
    }

    // Nodes far→near so near ones layer on top. Colour is depth-graded: far
    // nodes sink into indigo, near ones burn toward white — stronger 3D read.
    const white = Color(0xFFFFFFFF);
    final farCol = Color.lerp(DashColors.accent, const Color(0xFF4F46E5), 0.6)!;
    _order.sort((a, b) => _near[a].compareTo(_near[b]));
    for (final i in _order) {
      final near = _near[i];
      final f = _flare[i];
      final ex = _ex[i];
      var alpha = 0.25 + 0.65 * near;
      if (nodes[i].pulses) alpha *= 0.7 + 0.3 * sin(t * 2 + nodes[i].phase);
      alpha = (alpha + 0.55 * f + 0.5 * ex).clamp(0.0, 1.0);
      final c = Offset(_sx[i], _sy[i]);
      final rad = _rad[i] * (1 + 0.9 * f);
      var col = near < 0.5
          ? Color.lerp(farCol, DashColors.accent, near * 2)!
          : Color.lerp(DashColors.accent, white, (near - 0.5) * 0.7)!;
      if (ex > 0.05) col = Color.lerp(col, white, ex * 0.6)!;
      if ((model.glow.contains(i) && near > 0.4) || f > 0.3 || ex > 0.3) {
        _glow.color = col.withValues(alpha: (alpha * 0.5).clamp(0.0, 1.0));
        canvas.drawCircle(c, rad * 1.8, _glow);
      }
      _node.color = col.withValues(alpha: alpha);
      canvas.drawCircle(c, rad, _node);
      // Fresh cascade firing: one expanding ripple ring around the neuron.
      if (i < fire.length) {
        final dt = t - fire[i];
        if (dt >= 0 && dt < 0.9) {
          _ring.color = col.withValues(alpha: (1 - dt / 0.9) * 0.35);
          canvas.drawCircle(c, rad * 1.5 + dt * 26, _ring);
        }
      }
    }

    // Storm shockwaves: double expanding ring + core glow at the origin.
    for (final (sn, st0) in input.storms) {
      final age = t - st0;
      final fadeS = (1 - age / 2.5).clamp(0.0, 1.0);
      if (fadeS == 0) continue;
      final c = Offset(_sx[sn], _sy[sn]);
      final r = age * 1.35 * R * 0.78;
      _ring.color = DashColors.accent.withValues(alpha: 0.28 * fadeS);
      canvas.drawCircle(c, r, _ring);
      _ring.color = DashColors.accent.withValues(alpha: 0.12 * fadeS);
      canvas.drawCircle(c, r * 0.82, _ring);
      _glow.color = white.withValues(alpha: 0.5 * fadeS * exp(-age * 2));
      canvas.drawCircle(c, 14 * (1 - fadeS * 0.5), _glow);
    }

    // Travelling pulses with a short fading trail, on top of everything.
    final pulseCol = Color.lerp(DashColors.accent, const Color(0xFFFFFFFF), 0.55)!;
    for (final p in input.pulses) {
      final (a, b) = model.edges[p.edge];
      final prog = (t - p.t0) * p.speed;
      final fade = prog <= 1 ? 1.0 : (1 - (prog - 1) / 0.3).clamp(0.0, 1.0);
      for (var k = 0; k < 5; k++) {
        var q = prog - k * 0.06;
        if (q < 0 || q > 1) continue;
        if (p.reversed) q = 1 - q;
        final x = _sx[a] + (_sx[b] - _sx[a]) * q, y = _sy[a] + (_sy[b] - _sy[a]) * q;
        final aVal = (fade * (k == 0 ? 0.95 : 0.55 * (1 - k / 5))).clamp(0.0, 1.0);
        if (k == 0) {
          _glow.color = pulseCol.withValues(alpha: aVal * 0.6);
          canvas.drawCircle(Offset(x, y), 5, _glow);
        }
        _node.color = pulseCol.withValues(alpha: aVal);
        canvas.drawCircle(Offset(x, y), k == 0 ? 2.2 : 1.7 - k * 0.2, _node);
      }
    }
  }

  /// Two faint counter-rotating orbit rings with radial tick marks, behind the
  /// brain — flattened by the same camera tilt.
  void _rings(Canvas canvas, double cx, double cy, double R, double t, double tilt) {
    final squash = sin(tilt).abs().clamp(0.2, 1.0);
    for (final (r, rot, ticks) in [(R * 1.22, t * 2 * pi / 110, 72), (R * 1.42, -t * 2 * pi / 80, 48)]) {
      _ring.color = DashColors.accent.withValues(alpha: 0.05);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2 * squash), _ring);
      for (var i = 0; i < ticks; i++) {
        final a = rot + i * 2 * pi / ticks;
        final ca = cos(a), sa = sin(a);
        final long = i % 6 == 0;
        final r0 = r * (long ? 0.97 : 0.985), r1 = r * (long ? 1.03 : 1.015);
        _ring.color = DashColors.accent.withValues(alpha: long ? 0.14 : 0.07);
        canvas.drawLine(
          Offset(cx + ca * r0, cy + sa * r0 * squash),
          Offset(cx + ca * r1, cy + sa * r1 * squash),
          _ring,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BrainPainter old) => old.model != model || old.input != input;
}
