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

const _lateNight = [
  'Burning the midnight reactor again, Goofer?',
  "Late-night ops, Goofer. I'll keep the glow low.",
  "The city sleeps. The vault doesn't. Hey, Goofer.",
  'Past midnight, Goofer. Genius hours or bedtime?',
  '03:00 club, Goofer. Membership: you, me, the fridge.',
  'Deep night shift, Goofer. Even the cursor is yawning.',
  'Insomnia protocol engaged. Make it worth it, Goofer.',
  'The best commits happen after midnight. Allegedly, Goofer.',
];
const _dawn = [
  'Early boot sequence, Goofer. The sun is still compiling.',
  'Dawn patrol, Goofer. Systems warm, coffee pending.',
  'First light detected, Goofer. Reactor at minimum safe caffeine.',
  "You're up before the birds, Goofer. Respect.",
  'Cold boot at dawn, Goofer. All checks green.',
  'Sunrise imminent, Goofer. Initializing optimism module.',
  'Zero-dark-thirty, Goofer. The world is still buffering.',
  'Pre-dawn ops, Goofer. Quietest bandwidth of the day.',
];
const _morning = [
  'Good morning, Goofer. All systems nominal.',
  'Morning, Goofer. The vault kept watch while you slept.',
  "Daylight acquired. Let's make it count, Goofer.",
  'Rise and shine, Goofer. Telemetry looks promising.',
  'Systems nominal, Goofer. Coffee levels: unknown.',
  'Morning, Goofer. Today ships in daily increments.',
  'Fresh cache, clean slate. Good morning, Goofer.',
  'Solar array online, Goofer. Deploy the day.',
];
const _afternoon = [
  'Good afternoon, Goofer. Cruise altitude reached.',
  'Midday check-in, Goofer. Momentum holding steady.',
  'Afternoon, Goofer. Second wind loading…',
  'Solar peak passed. Plenty of runway left, Goofer.',
  'Afternoon, Goofer. Beware the post-lunch garbage collector.',
  'Halfway through the orbit, Goofer. Trajectory looks good.',
  'PM shift engaged, Goofer. Throttle at your discretion.',
  'Afternoon telemetry green across the board, Goofer.',
];
const _evening = [
  'Good evening, Goofer. Dimming the lights for you.',
  "Evening, Goofer. Time to log the day's findings.",
  "Sun's down, systems up. Welcome back, Goofer.",
  'Golden hour, Goofer. Wrap it up or wind it up.',
  'Evening, Goofer. Switching to low-power ambiance.',
  'Dusk detected, Goofer. The vault glows brighter now.',
  'Day cycle complete, Goofer. Ready for the debrief.',
  'Evening shift, Goofer. Best ideas arrive after sunset.',
];
const _night = [
  'Night mode, Goofer. The HUD suits the dark.',
  'Late hours, Goofer. Quality over quantity now.',
  'Nocturnal ops, Goofer. Noise floor: zero.',
  "The stars are out, Goofer. So are your notes.",
  'Night watch engaged, Goofer. I never blink.',
  'Quiet band reached, Goofer. Think in long sentences.',
  'Signal is cleanest at night, Goofer. Use it.',
  'Evening archive open, Goofer. File the day away.',
];

List<String> _pool(int hour) => switch (hour) {
      < 5 => _lateNight,
      < 8 => _dawn,
      < 12 => _morning,
      < 17 => _afternoon,
      < 21 => _evening,
      _ => _night,
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

/// "CAIRO — 34° CLEAR — WIND 12 KM/H" with a condition glyph, plus a second
/// line of detail readouts (humidity, precip odds, QNH, lunar phase); hidden
/// entirely when weather is unavailable.
class _WeatherRow extends ConsumerWidget {
  const _WeatherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider).value;
    if (w == null) return const SizedBox.shrink();
    final moon = MoonPhase.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
        ),
        const SizedBox(height: DashSpace.x1),
        Wrap(
          spacing: DashSpace.x3,
          runSpacing: DashSpace.x1,
          children: [
            _WxDetail('HUM', '${w.humidity}%'),
            _WxDetail('PRECIP', '${w.precipProb}%'),
            _WxDetail('QNH', '${w.qnhHpa.round()} HPA / ${w.qnhInHg.toStringAsFixed(2)} INHG'),
            _WxDetail('MOON', '${moon.glyph} ${moon.label}'),
          ],
        ),
      ],
    );
  }
}

/// Dim label + bright value pair, e.g. "HUM 62%".
class _WxDetail extends StatelessWidget {
  const _WxDetail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label ', style: DashType.hudLabel.copyWith(color: DashColors.text2)),
        TextSpan(text: value, style: DashType.hudLabel),
      ]),
    );
  }
}
