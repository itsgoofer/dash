import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/weather.dart';
import '../../theme/dash_theme.dart';
import 'stat_tiles.dart';

/// Dashboard hero: live clock + date + rotating greeting + weather readout on
/// the left, compact HUD stat chips on the right.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Clock(),
              SizedBox(height: DashSpace.x1),
              _DateLine(),
              SizedBox(height: DashSpace.x2),
              _Greeting(),
              SizedBox(height: DashSpace.x2),
              _WeatherRow(),
            ],
          ),
        ),
        const SizedBox(width: DashSpace.x4),
        const HudStatChips(),
      ],
    );
  }
}

/// Big Rajdhani clock, seconds ticking, colon blinking at 1 Hz.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final blink = now.second.isEven;
    return Text.rich(
      TextSpan(
        style: DashType.clock,
        children: [
          TextSpan(text: DateFormat('HH').format(now)),
          TextSpan(
            text: ':',
            style: TextStyle(color: DashColors.text0.withValues(alpha: blink ? 1 : 0.25)),
          ),
          TextSpan(text: DateFormat('mm').format(now)),
          TextSpan(
            text: ' ${DateFormat('ss').format(now)}',
            style: DashType.clockSmall.copyWith(color: DashColors.text1),
          ),
        ],
      ),
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final line = '${DateFormat('EEEE').format(now)} — ${DateFormat('MMMM d y').format(now)}'.toUpperCase();
    return Text(line, style: DashType.hudLabel);
  }
}

const _dawn = [
  'Early boot sequence, Goofer. The sun is still compiling.',
  'Dawn patrol, Goofer. Systems warm, coffee pending.',
  'First light detected, Goofer. Reactor at minimum safe caffeine.',
  "You're up before the birds, Goofer. Respect.",
];
const _morning = [
  'Good morning, Goofer. All systems nominal.',
  'Morning, Goofer. The vault kept watch while you slept.',
  "Daylight acquired. Let's make it count, Goofer.",
  'Rise and shine, Goofer. Telemetry looks promising.',
];
const _afternoon = [
  'Good afternoon, Goofer. Cruise altitude reached.',
  'Midday check-in, Goofer. Momentum holding steady.',
  'Afternoon, Goofer. Second wind loading…',
  'Solar peak passed. Plenty of runway left, Goofer.',
];
const _evening = [
  'Good evening, Goofer. Dimming the lights for you.',
  "Evening, Goofer. Time to log the day's findings.",
  "Sun's down, systems up. Welcome back, Goofer.",
  'Golden hour, Goofer. Wrap it up or wind it up.',
];
const _late = [
  'Burning the midnight reactor again, Goofer?',
  "Late-night ops, Goofer. I'll keep the glow low.",
  "The city sleeps. The vault doesn't. Hey, Goofer.",
  'Past midnight, Goofer. Genius hours or bedtime?',
];

List<String> _pool(int hour) => switch (hour) {
      >= 5 && < 8 => _dawn,
      >= 8 && < 12 => _morning,
      >= 12 && < 17 => _afternoon,
      >= 17 && < 22 => _evening,
      _ => _late,
    };

/// Time-of-day-aware greeting, picked at random on mount and cross-faded to a
/// fresh one every ~45s.
class _Greeting extends StatefulWidget {
  const _Greeting();

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  final _rnd = Random();
  String? _phrase;
  Timer? _timer;

  String _pick() {
    final pool = _pool(DateTime.now().hour);
    String next;
    do {
      next = pool[_rnd.nextInt(pool.length)];
    } while (pool.length > 1 && identical(next, _phrase));
    return next;
  }

  @override
  void initState() {
    super.initState();
    _phrase = _pick();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => setState(() => _phrase = _pick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: DashMotion.curve,
      switchOutCurve: DashMotion.curve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(_phrase ?? '', key: ValueKey(_phrase), style: DashType.title),
    );
  }
}

/// "CAIRO — 34° CLEAR — WIND 12 KM/H" with a condition glyph; hidden entirely
/// when weather is unavailable.
class _WeatherRow extends ConsumerWidget {
  const _WeatherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider).value;
    if (w == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(w.glyph, style: DashType.hudLabel.copyWith(color: DashColors.accent, fontSize: 13)),
        const SizedBox(width: DashSpace.x2),
        Flexible(
          child: Text(
            '${w.city} — ${w.tempC.round()}° ${w.label} — WIND ${w.windKmh.round()} KM/H',
            style: DashType.hudLabel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
