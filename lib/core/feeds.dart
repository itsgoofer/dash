import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Live external telemetry: top news headlines + market quotes, from keyless
/// public endpoints. Every field is TRUE — a failed source just yields an empty
/// list, never fake data. `null` state = wholly unavailable (consumers show an
/// OFFLINE line). Refreshes every ~15 minutes.
class Feeds {
  const Feeds({required this.headlines, required this.quotes, required this.fetchedAt});
  final List<String> headlines; // short story titles
  final List<(String sym, double last, double pct)> quotes; // symbol, last price, 24h %
  final DateTime fetchedAt;

  bool get isEmpty => headlines.isEmpty && quotes.isEmpty;
}

class FeedsNotifier extends AsyncNotifier<Feeds?> {
  Timer? _timer;

  @override
  Future<Feeds?> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) async => state = AsyncData(await _fetch()));
    ref.onDispose(() => _timer?.cancel());
    await Future.delayed(Duration(seconds: Random().nextInt(12))); // jittered start, stagger vs. other feeds
    return _fetch();
  }

  Future<Feeds?> _fetch() async {
    final results = await Future.wait([_headlines(), _quotes()]);
    final headlines = results[0] as List<String>;
    final quotes = results[1] as List<(String, double, double)>;
    if (headlines.isEmpty && quotes.isEmpty) return null;
    return Feeds(headlines: headlines, quotes: quotes, fetchedAt: DateTime.now());
  }

  /// Hacker News: top story ids → top ~5 titles, fetched concurrently.
  Future<List<String>> _headlines() async {
    try {
      final r = await http
          .get(Uri.parse('https://hacker-news.firebaseio.com/v0/topstories.json'))
          .timeout(const Duration(seconds: 7));
      final ids = (jsonDecode(r.body) as List).take(5).toList();
      final items = await Future.wait(ids.map((id) async {
        try {
          final ir = await http
              .get(Uri.parse('https://hacker-news.firebaseio.com/v0/item/$id.json'))
              .timeout(const Duration(seconds: 7));
          final t = (jsonDecode(ir.body) as Map?)?['title'];
          return t is String ? t : null;
        } catch (_) {
          return null;
        }
      }));
      return [for (final t in items) if (t != null) _clip(t, 60)];
    } catch (_) {
      return const [];
    }
  }

  /// CoinGecko simple price: last USD + real 24h % change (keyless, no key).
  Future<List<(String, double, double)>> _quotes() async {
    const ids = {'bitcoin': 'BTC', 'ethereum': 'ETH', 'solana': 'SOL', 'cardano': 'ADA'};
    try {
      final r = await http
          .get(Uri.parse('https://api.coingecko.com/api/v3/simple/price'
              '?ids=${ids.keys.join(',')}&vs_currencies=usd&include_24hr_change=true'))
          .timeout(const Duration(seconds: 8));
      final m = jsonDecode(r.body) as Map;
      return [
        for (final e in ids.entries)
          if (m[e.key] is Map && (m[e.key] as Map)['usd'] is num)
            (
              e.value,
              ((m[e.key] as Map)['usd'] as num).toDouble(),
              (((m[e.key] as Map)['usd_24h_change'] as num?) ?? 0).toDouble(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String _clip(String s, int n) {
    final t = s.trim();
    return t.length <= n ? t : '${t.substring(0, n - 1).trimRight()}…';
  }
}

final feedsProvider = AsyncNotifierProvider<FeedsNotifier, Feeds?>(FeedsNotifier.new);
