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
    required this.fetchedAt,
  });

  final String city;
  final double tempC;
  final String label; // short uppercase WMO condition, e.g. "PARTLY CLOUDY"
  final String glyph;
  final double windKmh;
  final DateTime fetchedAt;
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
              '?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m'))
          .timeout(const Duration(seconds: 8));
      final cur = (jsonDecode(r.body) as Map)['current'] as Map;
      final (label, glyph) = _wmo((cur['weather_code'] as num).toInt());
      return Weather(
        city: city.toUpperCase(),
        tempC: (cur['temperature_2m'] as num).toDouble(),
        label: label,
        glyph: glyph,
        windKmh: (cur['wind_speed_10m'] as num).toDouble(),
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
