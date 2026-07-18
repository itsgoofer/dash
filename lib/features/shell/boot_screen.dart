import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';

/// True once the boot choreography has finished (or was skipped). Boot plays
/// once per app launch — it never resets.
class BootCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final bootCompleteProvider = NotifierProvider<BootCompleteNotifier, bool>(BootCompleteNotifier.new);

/// Full-screen boot/index-loading overlay mounted above Shell in AppRoot.
///
/// Choreography (~2.4s, one controller with interval curves):
///   scanline sweep → "DASH" wordmark materializes (letter-spacing collapses
///   in, glow flickers to stable) → mono boot log types real vault data →
///   accent progress hairline → 300ms fade-out.
///
/// If the index is still scanning when the choreography reaches the fade-out
/// point, it holds (log shows INDEXING…) up to a hard 5s cap. Any key or
/// click skips instantly.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> with SingleTickerProviderStateMixin {
  static const _holdAt = 0.885; // fade-out starts here; hold for the index just before it
  static const _hardCap = Duration(seconds: 5);

  late final AnimationController _c;
  late final DateTime _start;
  Timer? _holdTimer;
  bool _held = false;
  final _focus = FocusNode(debugLabel: 'boot-skip');

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2700))
      ..addListener(_maybeHold)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      })
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  bool get _indexReady => ref.read(indexProvider).hasValue;
  bool get _pastCap => DateTime.now().difference(_start) >= _hardCap;

  /// Pause just before the fade-out until the index resolves (or the 5s cap).
  void _maybeHold() {
    if (_held || _c.value < _holdAt || _indexReady) return;
    _held = true;
    _c.stop();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (_indexReady || _pastCap) {
        t.cancel();
        _c.forward();
      }
    });
  }

  void _finish() => ref.read(bootCompleteProvider.notifier).complete();

  @override
  void dispose() {
    _holdTimer?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Choreography curves ────────────────────────────────────────────────────

  static final _scan = CurveTween(curve: const Interval(0.0, 0.16, curve: Curves.easeInOut));
  static final _mark = CurveTween(curve: const Interval(0.08, 0.34, curve: Curves.easeOutCubic));
  static final _glow = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.15), weight: 10), // stutter 1
    TweenSequenceItem(tween: Tween(begin: 0.15, end: 1.0), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 10), // stutter 2
    TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 45), // stable
  ]).chain(CurveTween(curve: const Interval(0.10, 0.42)));
  static final _log = CurveTween(curve: const Interval(0.30, 0.82, curve: Curves.easeInOutSine));
  static final _bar = CurveTween(curve: const Interval(0.06, 0.86, curve: Curves.easeInOutCubic));
  static final _fade = CurveTween(curve: const Interval(_holdAt, 1.0, curve: Curves.easeOut));

  List<String> _lines() {
    final vault = ref.watch(vaultPathProvider).value;
    final index = ref.watch(indexProvider);
    final accent = DashColors.accent;
    final hex = '#${(accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final idx = index.value;
    final nodes = idx == null
        ? null
        : idx.journalByDate.length +
            idx.projects.length +
            idx.entriesByDb.values.fold<int>(0, (n, e) => n + e.length);
    return [
      '> MOUNT      :: ${vault == null ? '—' : p.basename(vault).toUpperCase()} … OK',
      idx == null ? '> INDEX      :: INDEXING…' : '> INDEX      :: ${idx.byPath.length} NOTES REGISTERED',
      '> WATCHER    :: ONLINE',
      nodes == null ? '> NEURAL MAP :: STANDBY' : '> NEURAL MAP :: $nodes NODES MAPPED',
      '> ACCENT     :: $hex',
      '> ALL SYSTEMS NOMINAL',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        if (e is KeyDownEvent) _finish(); // skip instantly
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _finish(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final scan = _scan.transform(t);
            final mark = _mark.transform(t);
            final glow = _glow.transform(t);
            final log = _log.transform(t);
            final bar = _bar.transform(t);
            final accent = DashColors.accent;

            return Opacity(
              opacity: 1 - _fade.transform(t),
              child: Container(
                color: const Color(0xFF050609),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Thin scanline sweeping down the black frame.
                    if (scan > 0 && scan < 1)
                      Align(
                        alignment: Alignment(0, scan * 2 - 1),
                        child: Container(
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              accent.withValues(alpha: 0),
                              accent.withValues(alpha: 0.35 * (1 - scan)),
                              accent.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 2. Wordmark: letter-spacing collapses, glow flickers in.
                          Opacity(
                            opacity: mark,
                            child: Text(
                              'DASH',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 46,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 30 - 22 * mark,
                                color: DashColors.text0,
                                shadows: [
                                  Shadow(color: accent.withValues(alpha: 0.8 * glow), blurRadius: 22),
                                  Shadow(color: accent.withValues(alpha: 0.35 * glow), blurRadius: 48),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: DashSpace.x4),
                          // 4. Accent progress hairline.
                          SizedBox(
                            width: 260,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 2,
                                width: 260 * bar,
                                decoration: BoxDecoration(
                                  color: accent,
                                  boxShadow: [
                                    BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DashSpace.x4),
                          // 3. Mono boot log typing in, real data only.
                          SizedBox(
                            width: 340,
                            height: 130,
                            child: Text(
                              _revealed(lines, log),
                              style: DashType.ticker.copyWith(color: DashColors.text1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Types the log in character-by-character across [progress] 0→1, with a
  /// block cursor while mid-line.
  static String _revealed(List<String> lines, double progress) {
    if (progress <= 0) return '';
    final full = lines.join('\n');
    final shown = (full.length * progress).round().clamp(0, full.length);
    final text = full.substring(0, shown);
    return shown < full.length ? '$text█' : text;
  }
}
