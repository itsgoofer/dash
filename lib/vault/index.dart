import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/frontmatter.dart';
import '../core/models/db_schema.dart';
import '../core/models/note.dart';
import 'vault_fs.dart';

DateTime? _parseDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

bool isConflictedCopy(String path) => p.basename(path).contains('(conflicted copy');

/// In-memory vault index: frontmatter of every note, keyed several ways.
/// Immutable — watcher updates produce a new instance via [updateNote] /
/// [removeNote].
class VaultIndex {
  const VaultIndex({
    required this.rootPath,
    required this.byPath,
    required this.journalByDate,
    required this.entriesByDb,
    required this.projects,
    required this.schemas,
    required this.conflictedPaths,
  });

  final String rootPath;
  final Map<String, NoteMeta> byPath;
  final Map<DateTime, NoteMeta> journalByDate;
  final Map<String, List<NoteMeta>> entriesByDb;
  final List<NoteMeta> projects;
  final Map<String, DbSchema> schemas;
  final List<String> conflictedPaths;

  static Future<NoteMeta> readMeta(String rootPath, String relPath) async {
    final absPath = p.join(rootPath, relPath);
    final bytes = await File(absPath).readAsBytes();
    final stat = await File(absPath).stat();
    return _metaFromBytes(relPath, bytes, stat.modified);
  }

  /// Builds a [NoteMeta] straight from in-memory content (for optimistic
  /// index write-through right after a local save, before the watcher fires).
  static NoteMeta metaFromContent(String relPath, String content) =>
      _metaFromBytes(relPath, utf8.encode(content), DateTime.now());

  static final _wikiRe = RegExp(r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]');
  static final _tagRe = RegExp(r'(?<![\w#/])#([A-Za-z][\w/-]*)');

  /// Outgoing wikilink target names + tags (from body `#tag`s and a frontmatter
  /// `tags:` list/string), deduped.
  static (List<String>, List<String>) _linksAndTags(String body, Map<String, dynamic> data) {
    final links = <String>[];
    for (final m in _wikiRe.allMatches(body)) {
      final name = m.group(1)!.trim();
      if (name.isNotEmpty && !links.contains(name)) links.add(name);
    }
    final tags = <String>{for (final m in _tagRe.allMatches(body)) m.group(1)!};
    final fm = data['tags'];
    if (fm is List) {
      for (final t in fm) {
        final s = t.toString().trim();
        if (s.isNotEmpty) tags.add(s);
      }
    } else if (fm is String && fm.trim().isNotEmpty) {
      tags.add(fm.trim());
    }
    return (links, tags.toList());
  }

  static NoteMeta _metaFromBytes(String relPath, List<int> bytes, DateTime mtime) {
    final parsed = Frontmatter.parse(utf8.decode(bytes));
    final (links, tags) = _linksAndTags(parsed.body, parsed.data);
    return NoteMeta(
      path: relPath,
      type: NoteType.fromFrontmatter(parsed.data['type'] as String?),
      frontmatter: parsed.data,
      mtime: mtime,
      contentHash: fnv1a(bytes),
      links: links,
      tags: tags,
    );
  }

  /// Full scan: walks `**/*.md` (skipping dot-dirs), parses frontmatter only,
  /// and loads every `.dash/databases/*.yaml` schema.
  static Future<VaultIndex> scan(String rootPath) async {
    final byPath = <String, NoteMeta>{};
    final journalByDate = <DateTime, NoteMeta>{};
    final entriesByDb = <String, List<NoteMeta>>{};
    final projects = <NoteMeta>[];
    final conflictedPaths = <String>[];

    final root = Directory(rootPath);
    if (await root.exists()) {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        final rel = p.relative(entity.path, from: rootPath).replaceAll('\\', '/');
        if (rel.split('/').any((s) => s.startsWith('.'))) continue;

        final bytes = await entity.readAsBytes();
        final stat = await entity.stat();
        final meta = _metaFromBytes(rel, bytes, stat.modified);
        byPath[rel] = meta;
        if (isConflictedCopy(rel)) conflictedPaths.add(rel);
        _classify(meta, journalByDate, entriesByDb, projects);
      }
    }

    return VaultIndex(
      rootPath: rootPath,
      byPath: byPath,
      journalByDate: journalByDate,
      entriesByDb: entriesByDb,
      projects: projects,
      schemas: await _loadSchemas(rootPath),
      conflictedPaths: conflictedPaths,
    );
  }

  static void _classify(
    NoteMeta meta,
    Map<DateTime, NoteMeta> journalByDate,
    Map<String, List<NoteMeta>> entriesByDb,
    List<NoteMeta> projects,
  ) {
    switch (meta.type) {
      case NoteType.journal:
        final date = _parseDate(meta.frontmatter['date']);
        if (date != null) journalByDate[date] = meta;
      case NoteType.db:
        final db = meta.frontmatter['db'] as String?;
        if (db != null) entriesByDb.putIfAbsent(db, () => []).add(meta);
      case NoteType.project:
        projects.add(meta);
      case NoteType.note:
        break;
    }
  }

  static void _declassify(
    NoteMeta meta,
    Map<DateTime, NoteMeta> journalByDate,
    Map<String, List<NoteMeta>> entriesByDb,
    List<NoteMeta> projects,
  ) {
    switch (meta.type) {
      case NoteType.journal:
        final date = _parseDate(meta.frontmatter['date']);
        if (date != null) journalByDate.remove(date);
      case NoteType.db:
        final db = meta.frontmatter['db'] as String?;
        entriesByDb[db]?.removeWhere((m) => m.path == meta.path);
      case NoteType.project:
        projects.removeWhere((m) => m.path == meta.path);
      case NoteType.note:
        break;
    }
  }

  static Future<Map<String, DbSchema>> _loadSchemas(String rootPath) async {
    final dir = Directory(p.join(rootPath, '.dash', 'databases'));
    final schemas = <String, DbSchema>{};
    if (!await dir.exists()) return schemas;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.yaml')) continue;
      final yamlMap = loadYaml(await entity.readAsString());
      if (yamlMap is! Map) continue;
      schemas[p.basenameWithoutExtension(entity.path)] = DbSchema.fromYaml(yamlMap);
    }
    return schemas;
  }

  /// Applies an incremental add/change for [meta], returning a new index.
  VaultIndex updateNote(NoteMeta meta) {
    final newByPath = Map<String, NoteMeta>.of(byPath);
    final old = newByPath[meta.path];
    newByPath[meta.path] = meta;

    final newJournal = Map<DateTime, NoteMeta>.of(journalByDate);
    final newEntries = {for (final e in entriesByDb.entries) e.key: List<NoteMeta>.of(e.value)};
    final newProjects = List<NoteMeta>.of(projects);
    if (old != null) _declassify(old, newJournal, newEntries, newProjects);
    _classify(meta, newJournal, newEntries, newProjects);

    final newConflicted = List<String>.of(conflictedPaths)..remove(meta.path);
    if (isConflictedCopy(meta.path)) newConflicted.add(meta.path);

    return VaultIndex(
      rootPath: rootPath,
      byPath: newByPath,
      journalByDate: newJournal,
      entriesByDb: newEntries,
      projects: newProjects,
      schemas: schemas,
      conflictedPaths: newConflicted,
    );
  }

  /// Applies an incremental delete for [relPath], returning a new index.
  VaultIndex removeNote(String relPath) {
    final newByPath = Map<String, NoteMeta>.of(byPath);
    final old = newByPath.remove(relPath);
    if (old == null) return this;

    final newJournal = Map<DateTime, NoteMeta>.of(journalByDate);
    final newEntries = {for (final e in entriesByDb.entries) e.key: List<NoteMeta>.of(e.value)};
    final newProjects = List<NoteMeta>.of(projects);
    _declassify(old, newJournal, newEntries, newProjects);

    return VaultIndex(
      rootPath: rootPath,
      byPath: newByPath,
      journalByDate: newJournal,
      entriesByDb: newEntries,
      projects: newProjects,
      schemas: schemas,
      conflictedPaths: List<String>.of(conflictedPaths)..remove(relPath),
    );
  }
}
