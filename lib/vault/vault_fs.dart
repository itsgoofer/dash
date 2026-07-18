import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

/// Cheap, non-crypto content hash (FNV-1a, 32-bit) — good enough to detect
/// "did this file's bytes change" for watcher suppression / index diffing.
int fnv1a(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

class _ExpectedWrite {
  _ExpectedWrite(this.hash, this.expires);
  final int hash;
  final DateTime expires;
}

/// Pure file operations: read, atomic write, attachment save. Registers
/// self-writes so [VaultWatcher] can suppress the echo event they cause.
class VaultFs {
  VaultFs({DateTime Function()? clock, Duration? ttl})
    : _now = clock ?? DateTime.now,
      _ttl = ttl ?? const Duration(seconds: 3);

  final DateTime Function() _now;
  final Duration _ttl;
  final Map<String, _ExpectedWrite> _expectedWrites = {};

  Future<String> readNote(String absPath) => File(absPath).readAsString();

  /// Atomic write: `<path>.tmp` then rename over target. Creates parent dirs.
  Future<void> writeNote(String absPath, String content) async {
    final bytes = utf8.encode(content);
    await File(absPath).parent.create(recursive: true);
    _expectedWrites[absPath] = _ExpectedWrite(fnv1a(bytes), _now().add(_ttl));
    final tmp = File('$absPath.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(absPath);
  }

  /// True (and consumes the entry) if [absPath]/[hash] matches a write this
  /// process just made and the registration hasn't expired.
  bool isExpectedWrite(String absPath, int hash) {
    final ew = _expectedWrites[absPath];
    if (ew == null) return false;
    if (_now().isAfter(ew.expires) || ew.hash != hash) {
      _expectedWrites.remove(absPath);
      return false;
    }
    _expectedWrites.remove(absPath);
    return true;
  }

  /// Saves an attachment under `Attachments/<year>/`. Dragged files keep
  /// their basename (timestamp-suffixed only on collision); pasted data
  /// (`isPaste: true`) is named `img-<yyyyMMdd-HHmmss>[-n].<ext>`. Returns
  /// the vault-relative path.
  Future<String> saveAttachment(
    String vaultRoot,
    List<int> bytes, {
    required String originalName,
    bool isPaste = false,
  }) async {
    final year = DateTime.now().year.toString();
    final dirPath = p.join(vaultRoot, 'Attachments', year);
    await Directory(dirPath).create(recursive: true);

    final ext = p.extension(originalName).isEmpty ? '.png' : p.extension(originalName);
    final ts = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final base = isPaste ? 'img-$ts' : p.basenameWithoutExtension(originalName);

    var candidate = '$base$ext';
    var n = 1;
    while (await File(p.join(dirPath, candidate)).exists()) {
      candidate = '$base-$n$ext';
      n++;
    }

    await writeBytesAtomic(p.join(dirPath, candidate), bytes);
    return p.join('Attachments', year, candidate).replaceAll('\\', '/');
  }

  /// Deletes a note (used for database entries/schemas). No self-write
  /// registration needed — the watcher's `!exists()` check picks it up.
  Future<void> deleteNote(String absPath) async {
    final file = File(absPath);
    if (await file.exists()) await file.delete();
  }

  /// Recursively deletes a folder (database removal). Watcher rescan picks
  /// up the disappearance.
  Future<void> deleteFolder(String absPath) async {
    final dir = Directory(absPath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> writeBytesAtomic(String absPath, List<int> bytes) async {
    await File(absPath).parent.create(recursive: true);
    _expectedWrites[absPath] = _ExpectedWrite(fnv1a(bytes), _now().add(_ttl));
    final tmp = File('$absPath.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(absPath);
  }
}
