import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/frontmatter.dart';
import '../core/models/db_schema.dart';
import '../core/models/note.dart';
import '../core/tasks.dart';
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

// ─── Dashboard ────────────────────────────────────────────────────────────────

/// One day's charted metrics (frontmatter only). `null` fields = missing → gap.
class DayMetrics {
  const DayMetrics(this.date, this.rating, this.energy, this.productivity);
  final DateTime date;
  final int? rating, energy, productivity;

  bool get isEmpty => rating == null && energy == null && productivity == null;
}

/// Last 14 days (oldest→today) of rating/energy/productivity from the index.
final dashboardMetricsProvider = Provider<List<DayMetrics>>((ref) {
  final index = ref.watch(indexProvider).value;
  final today = _today();
  return List.generate(14, (i) {
    final d = DateTime(today.year, today.month, today.day - 13 + i);
    final fm = index?.journalByDate[d]?.frontmatter;
    int? m(String k) => fm != null && fm[k] is int ? fm[k] as int : null;
    return DayMetrics(d, m('rating'), m('energy'), m('productivity'));
  });
});

/// Rolled-up dashboard tile figures derived from the index.
class DashboardStats {
  const DashboardStats({
    required this.streak,
    required this.entriesThisWeek,
    required this.totalNotes,
    required this.activeProjects,
  });
  final int streak, entriesThisWeek, totalNotes, activeProjects;
  static const empty = DashboardStats(streak: 0, entriesThisWeek: 0, totalNotes: 0, activeProjects: 0);
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final index = ref.watch(indexProvider).value;
  if (index == null) return DashboardStats.empty;
  final today = _today();
  bool logged(DateTime d) => index.journalByDate.containsKey(DateTime(d.year, d.month, d.day));

  // Streak: consecutive logged days counting back from today (a not-yet-logged
  // today doesn't break a run that ended yesterday).
  var day = logged(today) ? today : DateTime(today.year, today.month, today.day - 1);
  var streak = 0;
  while (logged(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }

  final weekStart = DateTime(today.year, today.month, today.day - 6);
  final entriesThisWeek =
      index.journalByDate.keys.where((d) => !d.isBefore(weekStart) && !d.isAfter(today)).length;
  final activeProjects = index.projects.where((p) => p.frontmatter['status'] == 'active').length;

  return DashboardStats(
    streak: streak,
    entriesThisWeek: entriesThisWeek,
    totalNotes: index.byPath.length,
    activeProjects: activeProjects,
  );
});

/// Open (unchecked) task count across active projects, using the same cached,
/// hash-invalidated body reads as the projects list — only active projects'
/// bodies are read, never the whole vault.
final dashboardOpenTasksProvider = Provider<int>((ref) {
  final index = ref.watch(indexProvider).value;
  if (index == null) return 0;
  var total = 0;
  for (final proj in index.projects.where((p) => p.frontmatter['status'] == 'active')) {
    final counts = ref.watch(projectTaskCountsProvider(proj.path));
    total += (counts.value?.total ?? 0) - (counts.value?.done ?? 0);
  }
  return total;
});

// ─── Databases ──────────────────────────────────────────────────────────────

/// In-section navigation (db gallery → table → entry), no router — mirrors
/// [ShellSectionNotifier] one level down.
sealed class DatabasesView {
  const DatabasesView();
}

class DbListView extends DatabasesView {
  const DbListView();
}

class DbTableView extends DatabasesView {
  const DbTableView(this.slug);
  final String slug;
}

class DbEntryView extends DatabasesView {
  const DbEntryView(this.slug, {this.path});
  final String slug;
  final String? path; // null = new (unsaved) entry
}

class DatabasesNavNotifier extends Notifier<DatabasesView> {
  @override
  DatabasesView build() => const DbListView();

  void showList() => state = const DbListView();
  void showTable(String slug) => state = DbTableView(slug);
  void showEntry(String slug, {String? path}) => state = DbEntryView(slug, path: path);
}

final databasesNavProvider =
    NotifierProvider<DatabasesNavNotifier, DatabasesView>(DatabasesNavNotifier.new);

final dbSchemaProvider = Provider.family<DbSchema?, String>(
  (ref, slug) => ref.watch(indexProvider).value?.schemas[slug],
);

final dbRowsProvider = Provider.family<List<NoteMeta>, String>(
  (ref, slug) => ref.watch(indexProvider).value?.entriesByDb[slug] ?? const [],
);

typedef DbEntryKey = ({String slug, String? path});

/// Loaded db entry: typed field values (incl. `title`) + body, with
/// editing/dirty status — mirrors [JournalDoc].
class DbEntryDoc {
  const DbEntryDoc({
    required this.slug,
    required this.path,
    required this.fields,
    required this.body,
    required this.exists,
    this.dirty = false,
    this.changedOnDisk = false,
  });

  final String slug;
  final String? path; // vault-relative; null until first save
  final Map<String, dynamic> fields;
  final String body;
  final bool exists;
  final bool dirty;
  final bool changedOnDisk;

  DbEntryDoc copyWith({
    String? path,
    Map<String, dynamic>? fields,
    String? body,
    bool? exists,
    bool? dirty,
    bool? changedOnDisk,
  }) =>
      DbEntryDoc(
        slug: slug,
        path: path ?? this.path,
        fields: fields ?? this.fields,
        body: body ?? this.body,
        exists: exists ?? this.exists,
        dirty: dirty ?? this.dirty,
        changedOnDisk: changedOnDisk ?? this.changedOnDisk,
      );
}

const _deepEq = DeepCollectionEquality();

String _sanitizeTitle(String title) {
  final t = title.trim();
  return (t.isEmpty ? 'Untitled' : t).replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
}

/// Entry note for a database: loads fields+body, autosaves ~1s after the last
/// edit (renaming the file if the title changed), and reacts to external
/// on-disk changes — mirrors [JournalNoteNotifier].
class DbEntryNotifier extends AsyncNotifier<DbEntryDoc> {
  DbEntryNotifier(this.key);
  final DbEntryKey key;

  Timer? _timer;
  late String _root;
  String? _abs; // current on-disk absolute path; null if never saved
  int? _indexHash;

  /// Projects are the one built-in db whose notes use `type: project` (no
  /// `db:` key) per the vault format spec — every other db uses `type: db`.
  bool get _isProject => key.slug == 'projects';

  DbSchema get _schema => ref.read(indexProvider).value!.schemas[key.slug]!;
  List<String> get _keyOrder => [
        'type',
        if (!_isProject) 'db',
        ...(_schema.fields.map((f) => f.name)),
      ];

  String _absFor(String title) => p.join(_root, _schema.folder, '${_sanitizeTitle(title)}.md');
  String _relOf(String abs) => p.relative(abs, from: _root).replaceAll('\\', '/');

  @override
  Future<DbEntryDoc> build() async {
    _root = (await ref.read(vaultPathProvider.future))!;
    ref.onDispose(() => _timer?.cancel());

    if (key.path == null) {
      return DbEntryDoc(
        slug: key.slug,
        path: null,
        fields: {for (final f in _schema.fields) f.name: f.type == FieldType.checkbox ? false : null},
        body: '',
        exists: false,
      );
    }

    _abs = p.join(_root, key.path!);
    _indexHash = ref.read(indexProvider).value?.byPath[key.path!]?.contentHash;
    ref.listen(indexProvider, (_, next) {
      final h = next.value?.byPath[key.path!]?.contentHash;
      if (h == _indexHash) return;
      _indexHash = h;
      _onExternalChange();
    });
    return _readFromDisk();
  }

  Future<DbEntryDoc> _readFromDisk() async {
    final file = File(_abs!);
    if (!await file.exists()) {
      return DbEntryDoc(slug: key.slug, path: null, fields: const {}, body: '', exists: false);
    }
    final parsed = Frontmatter.parse(await file.readAsString());
    final fields = Map<String, dynamic>.of(parsed.data)
      ..remove('type')
      ..remove('db');
    return DbEntryDoc(slug: key.slug, path: _relOf(_abs!), fields: fields, body: parsed.body, exists: true);
  }

  void setField(String name, dynamic value) {
    final d = state.value;
    if (d == null) return;
    final fields = Map<String, dynamic>.of(d.fields)..[name] = value;
    state = AsyncData(d.copyWith(fields: fields, dirty: true));
    _schedule();
  }

  void setBody(String body) {
    final d = state.value;
    if (d == null || d.body == body) return;
    state = AsyncData(d.copyWith(body: body, dirty: true));
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), _flush);
  }

  Future<void> _flush() async {
    final d = state.value;
    if (d == null || !d.dirty) return;
    final title = (d.fields['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return; // needs a title before it can be written

    final newAbs = _absFor(title);
    final content = _serialize(d);
    await ref.read(vaultFsProvider).writeNote(newAbs, content);
    if (_abs != null && _abs != newAbs) {
      await ref.read(vaultFsProvider).deleteNote(_abs!);
    }
    _abs = newAbs;

    final cur = state.value;
    if (cur != null && cur.body == d.body && _deepEq.equals(cur.fields, d.fields)) {
      state = AsyncData(cur.copyWith(dirty: false, exists: true, path: _relOf(newAbs)));
    }
  }

  String _serialize(DbEntryDoc d) {
    final data = <String, dynamic>{
      'type': _isProject ? 'project' : 'db',
      if (!_isProject) 'db': key.slug,
      ...d.fields,
    };
    return Frontmatter.serialize(data, d.body, keyOrder: _keyOrder);
  }

  Future<void> _onExternalChange() async {
    final d = state.value;
    if (d == null || _abs == null) return;
    final incoming = await _readFromDisk();
    if (incoming.body == d.body && _deepEq.equals(incoming.fields, d.fields)) return;
    if (d.dirty) {
      state = AsyncData(d.copyWith(changedOnDisk: true));
    } else {
      state = AsyncData(incoming);
    }
  }

  /// Discards local edits and reloads from disk (banner "Reload" action).
  Future<void> reload() async {
    _timer?.cancel();
    if (_abs == null) return;
    state = AsyncData(await _readFromDisk());
  }
}

final dbEntryProvider =
    AsyncNotifierProvider.family<DbEntryNotifier, DbEntryDoc, DbEntryKey>(DbEntryNotifier.new);

// ─── Projects ───────────────────────────────────────────────────────────────

/// In-section navigation (list → detail), no router — mirrors [DatabasesView].
sealed class ProjectsView {
  const ProjectsView();
}

class ProjectsListView extends ProjectsView {
  const ProjectsListView();
}

class ProjectDetailView extends ProjectsView {
  const ProjectDetailView(this.path);
  final String path;
}

class ProjectsNavNotifier extends Notifier<ProjectsView> {
  @override
  ProjectsView build() => const ProjectsListView();

  void showList() => state = const ProjectsListView();
  void showDetail(String path) => state = ProjectDetailView(path);
}

final projectsNavProvider =
    NotifierProvider<ProjectsNavNotifier, ProjectsView>(ProjectsNavNotifier.new);

/// Cached done/total task count for the project note at [path]. Only
/// recomputes when that path's index content hash changes (family caching
/// keeps unrelated projects from being re-read), so cards can show progress
/// lazily without loading the whole vault's bodies.
final projectTaskCountsProvider = FutureProvider.family<TaskCounts, String>((ref, path) async {
  final hash = ref.watch(indexProvider.select((a) => a.value?.byPath[path]?.contentHash));
  if (hash == null) return TaskCounts.zero;
  final root = await ref.watch(vaultPathProvider.future);
  if (root == null) return TaskCounts.zero;
  final file = File(p.join(root, path));
  if (!await file.exists()) return TaskCounts.zero;
  return TaskCounts.from(Frontmatter.parse(await file.readAsString()).body);
});
