import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/frontmatter.dart';
import '../vault/index.dart';
import '../vault/vault_fs.dart';
import '../vault/vault_watcher.dart';

enum ShellSection { dashboard, journal, databases, projects }

class ShellSectionNotifier extends Notifier<ShellSection> {
  @override
  ShellSection build() => ShellSection.dashboard;

  void select(ShellSection section) => state = section;
}

final shellSectionProvider = NotifierProvider<ShellSectionNotifier, ShellSection>(
  ShellSectionNotifier.new,
);

const _kVaultPathKey = 'vault_path';

/// Last-opened vault path, persisted in shared_preferences. `null` means no
/// vault has been chosen yet — the shell shows the vault picker instead.
class VaultPathNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kVaultPathKey);
  }

  Future<void> setPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVaultPathKey, path);
    state = AsyncData(path);
  }
}

final vaultPathProvider = AsyncNotifierProvider<VaultPathNotifier, String?>(VaultPathNotifier.new);

final vaultFsProvider = Provider<VaultFs>((ref) => VaultFs());

/// Opens the current vault (scan + watch) and exposes its live [VaultIndex].
class IndexNotifier extends AsyncNotifier<VaultIndex> {
  VaultWatcher? _watcher;
  StreamSubscription<VaultChange>? _sub;

  @override
  Future<VaultIndex> build() async {
    final path = await ref.watch(vaultPathProvider.future);
    if (path == null) {
      throw StateError('No vault open');
    }

    final index = await VaultIndex.scan(path);
    final watcher = VaultWatcher(
      rootPath: path,
      vaultFs: ref.read(vaultFsProvider),
      currentIndex: () => state.value ?? index,
    );
    _watcher = watcher;
    _sub = watcher.changes.listen(_onChange);
    watcher.start();

    ref.onDispose(() {
      _sub?.cancel();
      _watcher?.dispose();
    });

    return index;
  }

  Future<void> _onChange(VaultChange change) async {
    final current = state.value;
    switch (change) {
      case NoteUpdated(:final meta):
        if (current != null) state = AsyncData(current.updateNote(meta));
      case NoteRemoved(:final path):
        if (current != null) state = AsyncData(current.removeNote(path));
      case RescanNeeded():
        final path = await ref.read(vaultPathProvider.future);
        if (path != null) state = AsyncData(await VaultIndex.scan(path));
    }
  }
}

final indexProvider = AsyncNotifierProvider<IndexNotifier, VaultIndex>(IndexNotifier.new);

// ─── Journal ────────────────────────────────────────────────────────────────

/// Metric keys in serialization order (after type/date). Metrics are 1–10 and
/// omitted from frontmatter when unset.
const journalMetrics = ['energy', 'rating', 'productivity', 'exercise', 'gaming'];
const _journalKeyOrder = ['type', 'date', ...journalMetrics];
final _dateFmt = DateFormat('yyyy-MM-dd');

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The day currently shown in the Journal screen (date-only), defaults to today.
class SelectedJournalDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => _today();

  void set(DateTime d) => state = DateTime(d.year, d.month, d.day);
  void previous() => state = DateTime(state.year, state.month, state.day - 1);
  void goToday() => state = _today();
  void next() {
    final n = DateTime(state.year, state.month, state.day + 1);
    if (!n.isAfter(_today())) state = n;
  }
}

final selectedJournalDateProvider =
    NotifierProvider<SelectedJournalDateNotifier, DateTime>(SelectedJournalDateNotifier.new);

/// Loaded journal document: body + metrics, with editing/dirty status. The file
/// may not exist yet — it's created lazily on first save.
class JournalDoc {
  const JournalDoc({
    required this.date,
    required this.body,
    required this.metrics,
    required this.exists,
    this.dirty = false,
    this.changedOnDisk = false,
  });

  final DateTime date;
  final String body;
  final Map<String, int> metrics;
  final bool exists;
  final bool dirty;
  final bool changedOnDisk;

  JournalDoc copyWith({String? body, Map<String, int>? metrics, bool? exists, bool? dirty, bool? changedOnDisk}) =>
      JournalDoc(
        date: date,
        body: body ?? this.body,
        metrics: metrics ?? this.metrics,
        exists: exists ?? this.exists,
        dirty: dirty ?? this.dirty,
        changedOnDisk: changedOnDisk ?? this.changedOnDisk,
      );
}

const _mapEq = MapEquality<String, int>();

/// Journal note for a given date: loads body+metrics, autosaves ~1s after the
/// last edit (atomic write, frontmatter in spec key order), and reacts to
/// external on-disk changes (clean → reload, dirty → banner).
class JournalNoteNotifier extends AsyncNotifier<JournalDoc> {
  JournalNoteNotifier(this.date);
  final DateTime date;

  Timer? _timer;
  late String _root;
  int? _indexHash; // last contentHash seen in the index for this file

  String get _rel => 'Journal/${date.year}/${_dateFmt.format(date)}.md';
  String get _abs => p.join(_root, _rel);

  @override
  Future<JournalDoc> build() async {
    _root = (await ref.read(vaultPathProvider.future))!;
    _indexHash = ref.read(indexProvider).value?.byPath[_rel]?.contentHash;

    ref.onDispose(() => _timer?.cancel());
    ref.listen(indexProvider, (_, next) {
      final h = next.value?.byPath[_rel]?.contentHash;
      if (h == _indexHash) return; // our file's index record didn't change
      _indexHash = h;
      _onExternalChange();
    });

    return _readFromDisk();
  }

  Future<JournalDoc> _readFromDisk() async {
    final file = File(_abs);
    if (!await file.exists()) return JournalDoc(date: date, body: '', metrics: const {}, exists: false);
    final parsed = Frontmatter.parse(await file.readAsString());
    return JournalDoc(date: date, body: parsed.body, metrics: _metricsFrom(parsed.data), exists: true);
  }

  Map<String, int> _metricsFrom(Map<String, dynamic> data) => {
        for (final k in journalMetrics)
          if (data[k] is int) k: data[k] as int,
      };

  void setBody(String body) {
    final d = state.value;
    if (d == null || d.body == body) return;
    state = AsyncData(d.copyWith(body: body, dirty: true));
    _schedule();
  }

  void setMetric(String key, int value) {
    final d = state.value;
    if (d == null) return;
    final m = Map<String, int>.of(d.metrics)..[key] = value;
    state = AsyncData(d.copyWith(metrics: m, dirty: true));
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), _flush);
  }

  Future<void> _flush() async {
    final d = state.value;
    if (d == null || !d.dirty) return;
    final content = _serialize(d);
    await ref.read(vaultFsProvider).writeNote(_abs, content);
    final cur = state.value;
    if (cur != null && cur.body == d.body && _mapEq.equals(cur.metrics, d.metrics)) {
      state = AsyncData(cur.copyWith(dirty: false, exists: true));
    }
  }

  String _serialize(JournalDoc d) {
    final data = <String, dynamic>{'type': 'journal', 'date': _dateFmt.format(d.date)};
    for (final k in journalMetrics) {
      if (d.metrics[k] != null) data[k] = d.metrics[k];
    }
    return Frontmatter.serialize(data, d.body, keyOrder: _journalKeyOrder);
  }

  Future<void> _onExternalChange() async {
    final d = state.value;
    if (d == null) return;
    final incoming = await _readFromDisk();
    if (incoming.body == d.body && _mapEq.equals(incoming.metrics, d.metrics)) return; // no real change
    if (d.dirty) {
      state = AsyncData(d.copyWith(changedOnDisk: true));
    } else {
      state = AsyncData(incoming);
    }
  }

  /// Discards local edits and reloads from disk (banner "Reload" action).
  Future<void> reload() async {
    _timer?.cancel();
    state = AsyncData(await _readFromDisk());
  }
}

final journalNoteProvider =
    AsyncNotifierProvider.family<JournalNoteNotifier, JournalDoc, DateTime>(JournalNoteNotifier.new);
