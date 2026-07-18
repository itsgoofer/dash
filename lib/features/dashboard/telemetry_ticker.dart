import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/weather.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import 'brain/brain_view.dart';

/// Scrolling sci-fi telemetry overlay: ~6 visible mono lines, every one TRUE,
/// computed from providers/system state. A new line types in every ~1.7s;
/// older lines shift up and dim. One Column + one Timer — no per-frame paint.
class TelemetryTicker extends ConsumerStatefulWidget {
  const TelemetryTicker({super.key});

  @override
  ConsumerState<TelemetryTicker> createState() => _TelemetryTickerState();
}

class _TelemetryTickerState extends ConsumerState<TelemetryTicker> {
  static final _launch = DateTime.now();
  static const _kGenerators = 9;
  final _lines = <String>[];
  Timer? _timer;
  int _kind = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _push());
    _timer = Timer.periodic(const Duration(milliseconds: 1700), (_) => _push());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _push() {
    if (!mounted) return;
    for (var i = 0; i < _kGenerators; i++) {
      final line = _gen(_kind++ % _kGenerators);
      if (line == null) continue;
      setState(() {
        _lines.add(line);
        if (_lines.length > 6) _lines.removeAt(0);
      });
      return;
    }
  }

  String? _gen(int k) {
    if (k <= 3 && ref.read(indexProvider).value == null) return null;
    final stats = ref.read(dashboardStatsProvider);
    switch (k) {
      case 0:
        return 'IDX ▸ ${stats.totalNotes} NOTES INDEXED';
      case 1:
        return stats.streak > 0 ? 'JRN ▸ JOURNAL STREAK ${stats.streak}D' : 'JRN ▸ NO ACTIVE STREAK';
      case 2:
        final t = ref.read(dashboardOpenTasksProvider);
        return 'TSK ▸ $t OPEN TASK${t == 1 ? '' : 'S'} IN ACTIVE PROJECTS';
      case 3:
        return 'LOG ▸ ${stats.entriesThisWeek}/7 ENTRIES THIS WEEK';
      case 4:
        final metas = ref.read(indexProvider).value?.byPath.values;
        if (metas == null || metas.isEmpty) return null;
        final m = metas.reduce((a, b) => a.mtime.isAfter(b.mtime) ? a : b);
        return 'MOD ▸ ${p.basenameWithoutExtension(m.path).toUpperCase()} — ${_rel(m.mtime)}';
      case 5:
        final up = DateTime.now().difference(_launch);
        final hh = up.inHours.toString().padLeft(2, '0');
        final mm = (up.inMinutes % 60).toString().padLeft(2, '0');
        final ss = (up.inSeconds % 60).toString().padLeft(2, '0');
        return 'SYS ▸ UPTIME $hh:$mm:$ss';
      case 6:
        final w = ref.read(weatherProvider).value;
        return w == null
            ? 'NET ▸ WEATHER LINK OFFLINE'
            : 'NET ▸ WX ${w.city} ${w.tempC.round()}° — SYNCED ${DateFormat('HH:mm').format(w.fetchedAt)}';
      case 7:
        final hex = DashColors.accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
        return 'HUD ▸ ACCENT #$hex';
      case 8:
        final b = brainStats.value;
        return b.nodes == 0 ? null : 'SYN ▸ CORTEX ${b.nodes} NODES / ${b.edges} LINKS';
    }
    return null;
  }

  static String _rel(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'JUST NOW';
    if (d.inHours < 1) return '${d.inMinutes}M AGO';
    if (d.inDays < 1) return '${d.inHours}H AGO';
    return '${d.inDays}D AGO';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _lines.length; i++)
            if (i == _lines.length - 1)
              _Typewriter(text: _lines[i])
            else
              Opacity(
                opacity: 0.35 + 0.45 * ((i + 1) / _lines.length),
                child: Text(_lines[i], style: DashType.ticker),
              ),
        ],
      ),
    );
  }
}

/// Reveals its text left-to-right over ~0.4s; restarts when the text changes.
class _Typewriter extends StatefulWidget {
  const _Typewriter({required this.text});
  final String text;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();

  @override
  void didUpdateWidget(_Typewriter old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final s = widget.text.substring(0, (_c.value * widget.text.length).round());
        return Text(
          s.isEmpty ? ' ' : s,
          style: DashType.ticker.copyWith(color: DashColors.text0.withValues(alpha: 0.85)),
        );
      },
    );
  }
}
