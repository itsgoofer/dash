import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Current conditions, geolocated by IP. `null` state = unavailable (offline,
/// blocked, parse error) — consumers simply hide their readouts.
class Weather {
  const Weather({
    required this.city,
    required this.tempC,
    required this.label,
    required this.glyph,
    required this.windKmh,
    required this.humidity,
    required this.qnhHpa,
    required this.precipProb,
    required this.fetchedAt,
  });

  final String city;
  final double tempC;
  final String label; // short uppercase WMO condition, e.g. "PARTLY CLOUDY"
  final String glyph;
  final double windKmh;
  final int humidity; // relative humidity, %
  final double qnhHpa; // mean-sea-level pressure (QNH)
  final int precipProb; // precipitation probability this hour, %
  final DateTime fetchedAt;

  double get qnhInHg => qnhHpa * 0.02952998;
}

/// Lunar phase computed locally from the mean synodic month; good to ~half a
/// day, plenty for a HUD readout.
class MoonPhase {
  const MoonPhase(this.label, this.glyph);
  final String label;
  final String glyph;

  static MoonPhase now() {
    const synodic = 29.530588853;
    final ref = DateTime.utc(2000, 1, 6, 18, 14); // known new moon
    final days = DateTime.now().toUtc().difference(ref).inMinutes / 1440.0;
    final f = (days / synodic) % 1.0; // 0 = new, 0.5 = full
    const phases = [
      MoonPhase('NEW MOON', '○'),
      MoonPhase('WAXING CRESCENT', '☽'),
      MoonPhase('FIRST QUARTER', '◐'),
      MoonPhase('WAXING GIBBOUS', '◕'),
      MoonPhase('FULL MOON', '●'),
      MoonPhase('WANING GIBBOUS', '◕'),
      MoonPhase('LAST QUARTER', '◑'),
      MoonPhase('WANING CRESCENT', '☾'),
    ];
    return phases[((f * 8) + 0.5).floor() % 8];
  }
}

/// IP geolocation (ipapi.co, fallback ipwho.is) → Open-Meteo current weather.
/// Refreshes every 30 minutes; any failure resolves to `null`, never an error.
class WeatherNotifier extends AsyncNotifier<Weather?> {
  Timer? _timer;

  @override
  Future<Weather?> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) async => state = AsyncData(await _fetch()));
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<Weather?> _fetch() async {
    try {
      final geo = await _geolocate();
      if (geo == null) return null;
      final (city, lat, lon) = geo;
      final r = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast'
              '?latitude=$lat&longitude=$lon'
              '&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,pressure_msl'
              '&hourly=precipitation_probability&forecast_days=1&timezone=auto'))
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(r.body) as Map;
      final cur = body['current'] as Map;
      final (label, glyph) = _wmo((cur['weather_code'] as num).toInt());
      final probs = ((body['hourly'] as Map?)?['precipitation_probability'] as List?) ?? const [];
      final hour = DateTime.now().hour;
      final prob = hour < probs.length ? (probs[hour] as num?)?.toInt() ?? 0 : 0;
      return Weather(
        city: city.toUpperCase(),
        tempC: (cur['temperature_2m'] as num).toDouble(),
        label: label,
        glyph: glyph,
        windKmh: (cur['wind_speed_10m'] as num).toDouble(),
        humidity: (cur['relative_humidity_2m'] as num).toInt(),
        qnhHpa: (cur['pressure_msl'] as num).toDouble(),
        precipProb: prob,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<(String, double, double)?> _geolocate() async {
    for (final url in ['https://ipapi.co/json/', 'https://ipwho.is/']) {
      try {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        final m = jsonDecode(r.body) as Map;
        final city = m['city'];
        final lat = m['latitude'], lon = m['longitude'];
        if (city is String && city.isNotEmpty && lat is num && lon is num) {
          return (city, lat.toDouble(), lon.toDouble());
        }
      } catch (_) {}
    }
    return null;
  }
}

/// WMO weather code → (short uppercase label, HUD glyph).
(String, String) _wmo(int code) => switch (code) {
      0 => ('CLEAR', '○'),
      1 => ('MAINLY CLEAR', '○'),
      2 => ('PARTLY CLOUDY', '◔'),
      3 => ('OVERCAST', '●'),
      45 || 48 => ('FOG', '≡'),
      >= 51 && <= 57 => ('DRIZZLE', '☂'),
      >= 61 && <= 67 => ('RAIN', '☂'),
      >= 71 && <= 77 => ('SNOW', '❄'),
      80 || 81 || 82 => ('SHOWERS', '☂'),
      85 || 86 => ('SNOW', '❄'),
      >= 95 => ('STORM', '↯'),
      _ => ('UNKNOWN', '◌'),
    };

final weatherProvider = AsyncNotifierProvider<WeatherNotifier, Weather?>(WeatherNotifier.new);
