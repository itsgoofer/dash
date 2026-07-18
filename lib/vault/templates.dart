import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/frontmatter.dart';

/// Reusable frontmatter+body templates, stored as `.md` files under
/// `.dash/templates/` (a dot-dir, so they're never indexed as real notes).
/// Applying one stamps its fields and body onto any project/database item.
String _dir(String root) => p.join(root, '.dash', 'templates');

typedef TemplateRef = ({String name, String path});

Future<List<TemplateRef>> listTemplates(String root) async {
  final dir = Directory(_dir(root));
  if (!await dir.exists()) return const [];
  final out = <TemplateRef>[];
  await for (final e in dir.list()) {
    if (e is File && e.path.endsWith('.md')) out.add((name: p.basenameWithoutExtension(e.path), path: e.path));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Loads a template's applicable fields (minus the entry-specific keys) + body.
Future<({Map<String, dynamic> fields, String body})> loadTemplate(String absPath) async {
  final parsed = Frontmatter.parse(await File(absPath).readAsString());
  final fields = Map<String, dynamic>.of(parsed.data)
    ..remove('type')
    ..remove('db')
    ..remove('title');
  return (fields: fields, body: parsed.body);
}

/// Saves the current item's frontmatter (minus entry-specific keys) + body as a
/// named template.
Future<void> saveTemplate(String root, String name, Map<String, dynamic> fields, String body) async {
  final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  final data = Map<String, dynamic>.of(fields)
    ..remove('type')
    ..remove('db')
    ..remove('title')
    ..remove('cover')
    ..remove('coverY');
  await Directory(_dir(root)).create(recursive: true);
  await File(p.join(_dir(root), '$safe.md')).writeAsString(Frontmatter.serialize({'type': 'template', ...data}, body));
}
