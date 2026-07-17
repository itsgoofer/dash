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

/// Lightweight index entry for a single note: frontmatter only, body lazy.
class NoteMeta {
  const NoteMeta({
    required this.path,
    required this.type,
    required this.frontmatter,
    required this.mtime,
    required this.contentHash,
  });

  /// Path relative to the vault root, forward-slash separated.
  final String path;
  final NoteType type;
  final Map<String, dynamic> frontmatter;
  final DateTime mtime;
  final int contentHash;
}
