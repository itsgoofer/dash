import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/frontmatter.dart';
import '../core/models/db_schema.dart';
import '../core/project_status.dart';
import '../core/models/note.dart';
import '../core/tasks.dart';
import '../theme/dash_theme.dart';
import '../vault/index.dart';
import '../vault/vault_fs.dart';
import '../vault/vault_watcher.dart';

enum ShellSection { dashboard, journal, notes, databases, projects }

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

/// Forces the note editor into read (`true`) or edit (`false`) mode across the
/// app; `null` = let each editor keep its own local toggle. Used by the shot
/// harness to prove the rendered read view.
class EditorReadModeNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  void set(bool? v) => state = v;
}

final editorReadModeProvider = NotifierProvider<EditorReadModeNotifier, bool?>(EditorReadModeNotifier.new);

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

  /// Reflects a just-saved note in the index immediately, without waiting for
  /// the filesystem watcher — the watcher later no-ops the echo (hash matches).
  void applyLocalWrite(String relPath, String content) {
    final current = state.value;
    if (current != null) state = AsyncData(current.updateNote(VaultIndex.metaFromContent(relPath, content)));
  }

  void applyLocalDelete(String relPath) {
    final current = state.value;
    if (current != null) state = AsyncData(current.removeNote(relPath));
  }

  int? hashOf(String relPath) => state.value?.byPath[relPath]?.contentHash;

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
const _journalKeyOrder = ['type', 'date', 'cover', 'coverY', ...journalMetrics];
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
    this.cover,
    this.coverY,
    this.dirty = false,
    this.changedOnDisk = false,
  });

  final DateTime date;
  final String body;
  final Map<String, int> metrics;
  final bool exists;
  final String? cover; // vault-relative cover image path (frontmatter `cover:`)
  final double? coverY; // cover vertical focal point 0..1 (frontmatter `coverY:`)
  final bool dirty;
  final bool changedOnDisk;

  static const Object _unset = Object();

  JournalDoc copyWith(
          {String? body,
          Map<String, int>? metrics,
          bool? exists,
          bool? dirty,
          bool? changedOnDisk,
          Object? cover = _unset,
          Object? coverY = _unset}) =>
      JournalDoc(
        date: date,
        body: body ?? this.body,
        metrics: metrics ?? this.metrics,
        exists: exists ?? this.exists,
        cover: identical(cover, _unset) ? this.cover : cover as String?,
        coverY: identical(coverY, _unset) ? this.coverY : coverY as double?,
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
  late VaultFs _fs;
  late IndexNotifier _index;
  int? _indexHash; // last contentHash seen in the index for this file

  String get _rel => 'Journal/${date.year}/${_dateFmt.format(date)}.md';
  String get _abs => p.join(_root, _rel);

  @override
  Future<JournalDoc> build() async {
    _root = (await ref.read(vaultPathProvider.future))!;
    _fs = ref.read(vaultFsProvider);
    _index = ref.read(indexProvider.notifier);
    _indexHash = ref.read(indexProvider).value?.byPath[_rel]?.contentHash;

    // Final save on teardown — navigating away before the debounce fires must
    // never lose an edit (a plain timer-cancel used to drop it silently).
    ref.onDispose(() {
      _timer?.cancel();
      final d = state.value;
      if (d != null && d.dirty) _persist(d);
    });
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
    final cover = parsed.data['cover'];
    final coverY = parsed.data['coverY'];
    return JournalDoc(
        date: date,
        body: parsed.body,
        metrics: _metricsFrom(parsed.data),
        exists: true,
        cover: cover is String ? cover : null,
        coverY: coverY is num ? coverY.toDouble() : null);
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

  void setCover(String? path) {
    final d = state.value;
    if (d == null || d.cover == path) return;
    state = AsyncData(d.copyWith(cover: path, coverY: path == null ? null : d.coverY, dirty: true));
    _schedule();
  }

  void setCoverY(double y) {
    final d = state.value;
    if (d == null || d.coverY == y) return;
    state = AsyncData(d.copyWith(coverY: y, dirty: true));
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
    _timer = Timer(const Duration(milliseconds: 400), _flush);
  }

  /// Writes to disk + reflects in the index. Touches no `state`, so it is safe
  /// to fire during dispose.
  Future<void> _persist(JournalDoc d) async {
    final content = _serialize(d);
    await _fs.writeNote(_abs, content);
    _index.applyLocalWrite(_rel, content); // instant dashboard/chart refresh
  }

  Future<void> _flush() async {
    final d = state.value;
    if (d == null || !d.dirty) return;
    await _persist(d);
    _indexHash = _index.hashOf(_rel); // our own write — don't treat as external
    final cur = state.value;
    if (cur != null && cur.body == d.body && cur.cover == d.cover && cur.coverY == d.coverY && _mapEq.equals(cur.metrics, d.metrics)) {
      state = AsyncData(cur.copyWith(dirty: false, exists: true));
    }
  }

  String _serialize(JournalDoc d) {
    final data = <String, dynamic>{'type': 'journal', 'date': _dateFmt.format(d.date)};
    if (d.cover != null) data['cover'] = d.cover;
    if (d.coverY != null) data['coverY'] = d.coverY;
    for (final k in journalMetrics) {
      if (d.metrics[k] != null) data[k] = d.metrics[k];
    }
    return Frontmatter.serialize(data, d.body, keyOrder: _journalKeyOrder);
  }

  Future<void> _onExternalChange() async {
    final d = state.value;
    if (d == null) return;
    final incoming = await _readFromDisk();
    if (incoming.body == d.body && incoming.cover == d.cover && incoming.coverY == d.coverY && _mapEq.equals(incoming.metrics, d.metrics)) {
      return; // no real change
    }
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
  final activeProjects = index.projects.where((p) => kActiveStatuses.contains(p.frontmatter['status'])).length;

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
  for (final proj in index.projects.where((p) => kActiveStatuses.contains(p.frontmatter['status']))) {
    final counts = ref.watch(projectTaskCountsProvider(proj.path));
    total += (counts.value?.total ?? 0) - (counts.value?.done ?? 0);
  }
  return total;
});

// ─── Link graph (tags & backlinks) ────────────────────────────────────────────

class LinkGraph {
  const LinkGraph(this.backlinks, this.tagToPaths, this.linkCount);
  final Map<String, List<String>> backlinks; // target path -> source paths
  final Map<String, List<String>> tagToPaths; // tag -> note paths
  final int linkCount; // total resolved links (drives brain-viz liveliness)
  static const empty = LinkGraph({}, {}, 0);
}

/// Whole-vault link/tag graph, rebuilt whenever the index changes. Wikilink
/// names resolve to a path by basename (then frontmatter title), case-insensitive.
final linkGraphProvider = Provider<LinkGraph>((ref) {
  final index = ref.watch(indexProvider).value;
  if (index == null) return LinkGraph.empty;
  final nameToPath = <String, String>{};
  for (final m in index.byPath.values) {
    nameToPath.putIfAbsent(p.basenameWithoutExtension(m.path).toLowerCase(), () => m.path);
    final t = m.frontmatter['title'];
    if (t is String && t.trim().isNotEmpty) nameToPath.putIfAbsent(t.toLowerCase(), () => m.path);
  }
  final backlinks = <String, List<String>>{};
  final tagToPaths = <String, List<String>>{};
  var linkCount = 0;
  for (final m in index.byPath.values) {
    for (final name in m.links) {
      final target = nameToPath[name.trim().toLowerCase()];
      if (target != null && target != m.path) {
        (backlinks[target] ??= []).add(m.path);
        linkCount++;
      }
    }
    for (final tag in m.tags) {
      (tagToPaths[tag] ??= []).add(m.path);
    }
  }
  return LinkGraph(backlinks, tagToPaths, linkCount);
});

/// Notes linking to [path] (for the backlinks panel), newest first.
final backlinksProvider = Provider.family<List<NoteMeta>, String>((ref, path) {
  final graph = ref.watch(linkGraphProvider);
  final index = ref.watch(indexProvider).value;
  if (index == null) return const [];
  return [for (final s in graph.backlinks[path] ?? const []) if (index.byPath[s] != null) index.byPath[s]!]
    ..sort((a, b) => b.mtime.compareTo(a.mtime));
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
  void showEntry(String slug, {String? path}) {
    // A "New entry" reuses the (slug, null) family key; invalidate so the form
    // opens blank instead of showing the previously-created entry's fields.
    if (path == null) ref.invalidate(dbEntryProvider((slug: slug, path: null)));
    state = DbEntryView(slug, path: path);
  }
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
  late VaultFs _fs;
  late IndexNotifier _index;
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
    _fs = ref.read(vaultFsProvider);
    _index = ref.read(indexProvider.notifier);
    // Final save on teardown — never drop a pending edit on navigation.
    ref.onDispose(() {
      _timer?.cancel();
      final d = state.value;
      if (d != null && d.dirty) _persist(d);
    });

    if (key.path == null) {
      return DbEntryDoc(
        slug: key.slug,
        path: null,
        fields: {
          for (final f in _schema.fields)
            f.name: switch (f.type) {
              FieldType.checkbox => false,
              FieldType.dynamicDate => _dateFmt.format(_today()), // auto-stamp today on creation
              _ => null,
            },
        },
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

  /// Sets one field and writes immediately — for inline table-cell edits.
  Future<void> commitField(String name, dynamic value) async {
    final d = state.value ?? await future;
    if (_deepEq.equals(d.fields[name], value)) return;
    state = AsyncData(d.copyWith(fields: {...d.fields, name: value}, dirty: true));
    _timer?.cancel();
    await _flush();
  }

  void setBody(String body) {
    final d = state.value;
    if (d == null || d.body == body) return;
    state = AsyncData(d.copyWith(body: body, dirty: true));
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _flush);
  }

  /// True once there's anything worth saving — a title, body, or any set field.
  /// A blank new entry stays unwritten so navigation doesn't litter the vault.
  bool _hasContent(DbEntryDoc d) {
    if (((d.fields['title'] as String?)?.trim().isNotEmpty ?? false) || d.body.trim().isNotEmpty) return true;
    // Auto-stamped dynamic-date fields don't count as user intent — otherwise
    // merely opening "New entry" would create an Untitled note on navigation.
    final auto = {for (final f in _schema.fields) if (f.type == FieldType.dynamicDate) f.name};
    return d.fields.entries.any((e) => e.key != 'title' && !auto.contains(e.key) && e.value != null && e.value != false && e.value != '');
  }

  /// Writes to disk (renaming on title change) + reflects in the index.
  /// Touches no `state`, so it is safe to fire during dispose. Returns the new
  /// vault-relative path, or null if there was nothing to save.
  Future<String?> _persist(DbEntryDoc d) async {
    if (!_hasContent(d)) return null;
    final title = (d.fields['title'] as String?)?.trim() ?? '';
    final newAbs = _absFor(title); // _sanitizeTitle defaults '' → 'Untitled'
    final content = _serialize(d);
    await _fs.writeNote(newAbs, content);
    final old = _abs;
    if (old != null && old != newAbs) {
      await _fs.deleteNote(old);
      _index.applyLocalDelete(_relOf(old));
    }
    _abs = newAbs;
    final rel = _relOf(newAbs);
    _index.applyLocalWrite(rel, content); // instant table/count refresh
    return rel;
  }

  Future<void> _flush() async {
    final d = state.value;
    if (d == null || !d.dirty) return;
    final rel = await _persist(d);
    if (rel == null) return;
    _indexHash = _index.hashOf(rel);
    final cur = state.value;
    if (cur != null && cur.body == d.body && _deepEq.equals(cur.fields, d.fields)) {
      state = AsyncData(cur.copyWith(dirty: false, exists: true, path: rel));
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

// ─── Notes (plain markdown) ───────────────────────────────────────────────────

/// A plain, non-database note: title (= filename) + body, with any frontmatter
/// preserved verbatim. Loaded/saved through the same write-through +
/// flush-on-dispose pipeline as journal/db notes.
class PlainNoteDoc {
  const PlainNoteDoc({
    required this.path,
    required this.title,
    required this.body,
    required this.frontmatter,
    required this.exists,
    this.dirty = false,
    this.changedOnDisk = false,
  });

  final String path; // vault-relative
  final String title;
  final String body;
  final Map<String, dynamic> frontmatter; // preserved verbatim on save
  final bool exists, dirty, changedOnDisk;

  PlainNoteDoc copyWith({String? body, Map<String, dynamic>? frontmatter, bool? exists, bool? dirty, bool? changedOnDisk}) =>
      PlainNoteDoc(
        path: path,
        title: title,
        body: body ?? this.body,
        frontmatter: frontmatter ?? this.frontmatter,
        exists: exists ?? this.exists,
        dirty: dirty ?? this.dirty,
        changedOnDisk: changedOnDisk ?? this.changedOnDisk,
      );
}

class PlainNoteNotifier extends AsyncNotifier<PlainNoteDoc> {
  PlainNoteNotifier(this.path);
  final String path; // vault-relative; the file is created before it's opened

  Timer? _timer;
  late String _root;
  late VaultFs _fs;
  late IndexNotifier _index;
  int? _indexHash;

  String get _abs => p.join(_root, path);

  @override
  Future<PlainNoteDoc> build() async {
    _root = (await ref.read(vaultPathProvider.future))!;
    _fs = ref.read(vaultFsProvider);
    _index = ref.read(indexProvider.notifier);
    _indexHash = _index.hashOf(path);
    ref.onDispose(() {
      _timer?.cancel();
      final d = state.value;
      if (d != null && d.dirty) _persist(d);
    });
    ref.listen(indexProvider, (_, next) {
      final h = next.value?.byPath[path]?.contentHash;
      if (h == _indexHash) return;
      _indexHash = h;
      _onExternalChange();
    });
    return _readFromDisk();
  }

  Future<PlainNoteDoc> _readFromDisk() async {
    final title = p.basenameWithoutExtension(path);
    final file = File(_abs);
    if (!await file.exists()) {
      return PlainNoteDoc(path: path, title: title, body: '', frontmatter: const {}, exists: false);
    }
    final parsed = Frontmatter.parse(await file.readAsString());
    return PlainNoteDoc(path: path, title: title, body: parsed.body, frontmatter: parsed.data, exists: true);
  }

  void setBody(String body) {
    final d = state.value;
    if (d == null || d.body == body) return;
    state = AsyncData(d.copyWith(body: body, dirty: true));
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _flush);
  }

  Future<void> _persist(PlainNoteDoc d) async {
    // Keep plain notes fence-free when they have no frontmatter.
    final content = d.frontmatter.isEmpty ? d.body : Frontmatter.serialize(d.frontmatter, d.body);
    await _fs.writeNote(_abs, content);
    _index.applyLocalWrite(path, content);
  }

  Future<void> _flush() async {
    final d = state.value;
    if (d == null || !d.dirty) return;
    await _persist(d);
    _indexHash = _index.hashOf(path);
    final cur = state.value;
    if (cur != null && cur.body == d.body) state = AsyncData(cur.copyWith(dirty: false, exists: true));
  }

  Future<void> _onExternalChange() async {
    final d = state.value;
    if (d == null) return;
    final incoming = await _readFromDisk();
    if (incoming.body == d.body) return;
    state = AsyncData(d.dirty ? d.copyWith(changedOnDisk: true) : incoming);
  }

  Future<void> reload() async {
    _timer?.cancel();
    state = AsyncData(await _readFromDisk());
  }
}

final plainNoteProvider =
    AsyncNotifierProvider.family<PlainNoteNotifier, PlainNoteDoc, String>(PlainNoteNotifier.new);

/// All plain (untyped) notes, newest first — the Notes section's list.
final notesListProvider = Provider<List<NoteMeta>>((ref) {
  final index = ref.watch(indexProvider).value;
  if (index == null) return const [];
  final list = index.byPath.values.where((m) => m.type == NoteType.note && !isConflictedCopy(m.path)).toList()
    ..sort((a, b) => b.mtime.compareTo(a.mtime));
  return list;
});

/// In-section navigation for Notes (list ↔ detail).
sealed class NotesView {
  const NotesView();
}

class NotesListView extends NotesView {
  const NotesListView();
}

class NoteDetailView extends NotesView {
  const NoteDetailView(this.path);
  final String path;
}

class NotesNavNotifier extends Notifier<NotesView> {
  @override
  NotesView build() => const NotesListView();
  void showList() => state = const NotesListView();
  void showDetail(String path) => state = NoteDetailView(path);
}

final notesNavProvider = NotifierProvider<NotesNavNotifier, NotesView>(NotesNavNotifier.new);

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

/// Vault-persisted accent color (name from DashColors.accents). Setting it
/// mutates DashColors.accent and bumps state so DashApp rebuilds its theme.
class AccentNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final root = await ref.watch(vaultPathProvider.future);
    var name = 'cyan';
    if (root != null) {
      final f = File(p.join(root, '.dash', 'settings.yaml'));
      if (await f.exists()) {
        final m = RegExp(r'^accent:\s*(\w+)', multiLine: true).firstMatch(await f.readAsString());
        if (m != null && DashColors.accents.containsKey(m.group(1))) name = m.group(1)!;
      }
    }
    DashColors.accent = DashColors.accents[name]!;
    return name;
  }

  Future<void> set(String name) async {
    if (!DashColors.accents.containsKey(name)) return;
    DashColors.accent = DashColors.accents[name]!;
    state = AsyncData(name);
    final root = ref.read(vaultPathProvider).value;
    if (root == null) return;
    final f = File(p.join(root, '.dash', 'settings.yaml'));
    var text = await f.exists() ? await f.readAsString() : '';
    text = text.replaceAll(RegExp(r'^accent:.*\n?', multiLine: true), '');
    if (text.isNotEmpty && !text.endsWith('\n')) text += '\n';
    await f.writeAsString('${text}accent: $name\n');
  }
}

final accentProvider = AsyncNotifierProvider<AccentNotifier, String>(AccentNotifier.new);
