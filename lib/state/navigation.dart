import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/models/note.dart';
import '../vault/index.dart';
import 'providers.dart';

/// Resolves a `[[wikilink]]` target name to an existing note (basename first,
/// then frontmatter title, case-insensitive). Null if no such note exists.
NoteMeta? resolveWikilink(VaultIndex? index, String name) {
  if (index == null) return null;
  final lower = name.trim().toLowerCase();
  for (final m in index.byPath.values) {
    if (p.basenameWithoutExtension(m.path).toLowerCase() == lower) return m;
  }
  for (final m in index.byPath.values) {
    final t = m.frontmatter['title'];
    if (t is String && t.toLowerCase() == lower) return m;
  }
  return null;
}

/// Deep-links to [note] in the correct section — shared by the command palette,
/// wikilink clicks, and the backlinks panel.
void openNote(WidgetRef ref, NoteMeta note) {
  final shell = ref.read(shellSectionProvider.notifier);
  switch (note.type) {
    case NoteType.journal:
      final raw = note.frontmatter['date'];
      final date = raw is DateTime ? raw : DateTime.tryParse(raw?.toString() ?? '');
      if (date != null) ref.read(selectedJournalDateProvider.notifier).set(date);
      shell.select(ShellSection.journal);
    case NoteType.db:
      final slug = note.frontmatter['db'] as String?;
      slug != null
          ? ref.read(databasesNavProvider.notifier).showEntry(slug, path: note.path)
          : ref.read(databasesNavProvider.notifier).showList();
      shell.select(ShellSection.databases);
    case NoteType.project:
      ref.read(projectsNavProvider.notifier).showDetail(note.path);
      shell.select(ShellSection.projects);
    case NoteType.note:
      ref.read(notesNavProvider.notifier).showDetail(note.path);
      shell.select(ShellSection.notes);
  }
}
