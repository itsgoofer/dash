import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'vault_scaffold.dart';

/// Directory picker shared by the first-run picker and the vault menu.
Future<String?> pickVaultDir() => FilePicker.getDirectoryPath();

/// Scaffolds a fresh vault into [dir] (thin alias so callers only import here).
Future<void> createVaultAt(String dir) => scaffoldVault(dir);

/// True if [dir] is a sane "open" target: has a `.dash/` config, any `.md`
/// file, or is essentially empty (safe to adopt).
Future<bool> looksLikeVault(String dir) async {
  if (await Directory(p.join(dir, '.dash')).exists()) return true;
  var empty = true;
  await for (final e in Directory(dir).list()) {
    empty = false;
    if (e is File && p.extension(e.path) == '.md') return true;
  }
  return empty;
}

/// Moves the vault at [current] into `[destParent]/<vault-folder-name>`, via
/// [Directory.rename] with a copy-then-delete fallback across volumes. Returns
/// the new vault path. Refuses to move a vault into itself/a child of itself.
Future<String> moveVault(String current, String destParent) async {
  final target = p.join(destParent, p.basename(current));
  if (p.equals(current, target) || p.isWithin(current, target)) {
    throw ArgumentError('Cannot move a vault into itself.');
  }
  final src = Directory(current);
  try {
    await src.rename(target);
  } on FileSystemException {
    await _copyDir(src, Directory(target));
    await src.delete(recursive: true);
  }
  return target;
}

Future<void> _copyDir(Directory src, Directory dst) async {
  await dst.create(recursive: true);
  await for (final e in src.list()) {
    final into = p.join(dst.path, p.basename(e.path));
    if (e is Directory) {
      await _copyDir(e, Directory(into));
    } else if (e is File) {
      await e.copy(into);
    } else if (e is Link) {
      await Link(into).create(await e.target());
    }
  }
}
