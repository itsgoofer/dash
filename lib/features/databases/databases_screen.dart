import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'db_list_screen.dart';
import 'db_table_view.dart';
import 'entry_form.dart';

/// Top-level Databases section: db gallery → table → entry, switched by
/// [databasesNavProvider] — no router, mirrors the Shell's own switching.
class DatabasesScreen extends ConsumerWidget {
  const DatabasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(databasesNavProvider);
    final key = switch (view) {
      DbListView() => 'list',
      DbTableView(:final slug) => 'table-$slug',
      DbEntryView(:final slug, :final path) => 'entry-$slug-$path',
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(key),
        child: switch (view) {
          DbListView() => const DbListScreen(),
          DbTableView(:final slug) => DbTableScreen(slug: slug),
          DbEntryView(:final slug, :final path) => EntryForm(slug: slug, path: path),
        },
      ),
    );
  }
}
