import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
