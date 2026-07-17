import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../core/frontmatter.dart';
import '../core/models/note.dart';
import 'index.dart';
import 'vault_fs.dart';

sealed class VaultChange {
  const VaultChange();
}

class NoteUpdated extends VaultChange {
  const NoteUpdated(this.meta);
  final NoteMeta meta;
}

class NoteRemoved extends VaultChange {
  const NoteRemoved(this.path);
  final String path;
}

class RescanNeeded extends VaultChange {
  const RescanNeeded();
}

/// Watches the vault root for `.md` changes, debounces bursts, skips
/// self-writes (via [VaultFs.isExpectedWrite]) and no-op hash matches, and
/// emits [VaultChange]s for the index to apply.
class VaultWatcher {
  VaultWatcher({
    required this.rootPath,
    required this.vaultFs,
    required this.currentIndex,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String rootPath;
  final VaultFs vaultFs;
  final VaultIndex Function() currentIndex;
  final Duration debounce;

  StreamSubscription<WatchEvent>? _sub;
  Timer? _debounceTimer;
  final Set<String> _pending = {};
  final _controller = StreamController<VaultChange>.broadcast();

  Stream<VaultChange> get changes => _controller.stream;

  void start() {
    final watcher = DirectoryWatcher(rootPath);
    _sub = watcher.events.listen(_onEvent, onError: (_) => _controller.add(const RescanNeeded()));
  }

  void _onEvent(WatchEvent event) {
    final rel = p.relative(event.path, from: rootPath).replaceAll('\\', '/');
    final segments = rel.split('/');
    // Config/schema changes (or anything under a dot-dir) are rare and cheap
    // to handle uniformly: just rescan.
    if (segments.any((s) => s.startsWith('.'))) {
      _controller.add(const RescanNeeded());
      return;
    }
    if (!event.path.endsWith('.md')) return;
    _pending.add(event.path);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _flush);
  }

  Future<void> _flush() async {
    final paths = _pending.toList();
    _pending.clear();
    for (final absPath in paths) {
      await _handle(absPath);
    }
  }

  Future<void> _handle(String absPath) async {
    final rel = p.relative(absPath, from: rootPath).replaceAll('\\', '/');
    final file = File(absPath);
    if (!await file.exists()) {
      _controller.add(NoteRemoved(rel));
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final hash = fnv1a(bytes);
      if (vaultFs.isExpectedWrite(absPath, hash)) return;
      if (currentIndex().byPath[rel]?.contentHash == hash) return;

      final stat = await file.stat();
      final parsed = Frontmatter.parse(utf8.decode(bytes));
      _controller.add(
        NoteUpdated(
          NoteMeta(
            path: rel,
            type: NoteType.fromFrontmatter(parsed.data['type'] as String?),
            frontmatter: parsed.data,
            mtime: stat.modified,
            contentHash: hash,
          ),
        ),
      );
    } catch (_) {
      _controller.add(const RescanNeeded());
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}
