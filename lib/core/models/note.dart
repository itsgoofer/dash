/// Classification of a note by its `type:` frontmatter field.
enum NoteType {
  journal,
  db,
  project,
  note;

  static NoteType fromFrontmatter(String? type) => switch (type) {
    'journal' => NoteType.journal,
    'db' => NoteType.db,
    'project' => NoteType.project,
    _ => NoteType.note,
  };
}

/// Lightweight index entry for a single note: frontmatter + link/tag graph
/// data extracted from the body (kept cheap — no full body retained).
class NoteMeta {
  const NoteMeta({
    required this.path,
    required this.type,
    required this.frontmatter,
    required this.mtime,
    required this.contentHash,
    this.links = const [],
    this.tags = const [],
  });

  /// Path relative to the vault root, forward-slash separated.
  final String path;
  final NoteType type;
  final Map<String, dynamic> frontmatter;
  final DateTime mtime;
  final int contentHash;

  /// Outgoing `[[wikilink]]` target names (as written), and `#tags` (body +
  /// frontmatter). Resolved to a graph by `linkGraphProvider`.
  final List<String> links;
  final List<String> tags;
}
