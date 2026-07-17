import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/db_schema.dart';
import '../../core/models/note.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/empty_state.dart';
import 'db_widgets.dart';

/// Sortable, typed table of one database's entries.
class DbTableScreen extends ConsumerStatefulWidget {
  const DbTableScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<DbTableScreen> createState() => _DbTableScreenState();
}

class _DbTableScreenState extends ConsumerState<DbTableScreen> {
  int _sortCol = 0;
  bool _asc = true;

  dynamic _valueOf(NoteMeta m, String col) => m.frontmatter[col];

  @override
  Widget build(BuildContext context) {
    final schema = ref.watch(dbSchemaProvider(widget.slug));
    if (schema == null) return const SizedBox.shrink();

    final columns = [for (final f in schema.fields) f.name];
    final rows = List<NoteMeta>.of(ref.watch(dbRowsProvider(widget.slug)));
    final sortCol = _sortCol < columns.length ? _sortCol : 0;
    rows.sort((a, b) {
      final av = _valueOf(a, columns[sortCol]);
      final bv = _valueOf(b, columns[sortCol]);
      final cmp = Comparable.compare(av?.toString() ?? '', bv?.toString() ?? '');
      return _asc ? cmp : -cmp;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackNavButton(onTap: () => ref.read(databasesNavProvider.notifier).showList()),
            const SizedBox(width: DashSpace.x2),
            Text(schema.name, style: DashType.display),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => ref.read(databasesNavProvider.notifier).showEntry(widget.slug),
              icon: const DashIcon('add', size: 16, color: DashColors.bg0),
              label: const Text('New entry'),
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x4),
        Expanded(
          child: rows.isEmpty
              ? const EmptyState(icon: 'database', message: 'No entries yet.')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderRow(
                        columns: columns,
                        sortCol: sortCol,
                        asc: _asc,
                        onSort: (i) => setState(() {
                          if (_sortCol == i) {
                            _asc = !_asc;
                          } else {
                            _sortCol = i;
                            _asc = true;
                          }
                        }),
                      ),
                      for (final row in rows)
                        _EntryRow(
                          row: row,
                          columns: columns,
                          schema: schema,
                          onOpen: () => ref.read(databasesNavProvider.notifier).showEntry(widget.slug, path: row.path),
                          onDelete: () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Delete entry?',
                              message: 'This permanently deletes "${row.frontmatter['title'] ?? row.path}".',
                            );
                            if (!ok) return;
                            final root = ref.read(vaultPathProvider).value;
                            if (root == null) return;
                            await ref.read(vaultFsProvider).deleteNote(p.join(root, row.path));
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.sortCol, required this.asc, required this.onSort});
  final List<String> columns;
  final int sortCol;
  final bool asc;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: DashColors.glassBorder))),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSort(i),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(columns[i], style: DashType.heading.copyWith(fontSize: 13, color: DashColors.text1)),
                    if (sortCol == i) ...[
                      const SizedBox(width: DashSpace.x1),
                      DashIcon(asc ? 'arrow_upward' : 'arrow_downward', size: 14, color: DashColors.accent),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(width: 64), // actions column
        ],
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.row,
    required this.columns,
    required this.schema,
    required this.onOpen,
    required this.onDelete,
  });

  final NoteMeta row;
  final List<String> columns;
  final DbSchema schema;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hovering = false;

  DbField? _fieldFor(String name) => widget.schema.fields.where((f) => f.name == name).firstOrNull;

  Widget _cell(String col) {
    final field = _fieldFor(col);
    final value = widget.row.frontmatter[col];
    if (value == null) return const SizedBox.shrink();

    return switch (field?.type) {
      FieldType.number => Text(value.toString(), style: DashType.mono),
      FieldType.checkbox => value == true
          ? DashIcon('check', size: 16, color: DashColors.accent)
          : const SizedBox.shrink(),
      FieldType.select => Align(
          alignment: Alignment.centerLeft,
          child: DashChip(value.toString(), color: DashChip.optionColor(value.toString())),
        ),
      FieldType.multiselect => Wrap(
          spacing: 4,
          children: [
            for (final v in (value as List))
              DashChip(v.toString(), color: DashChip.optionColor(v.toString()))
          ],
        ),
      FieldType.date => Text(value.toString(), style: DashType.small),
      FieldType.url => Text(value.toString(), style: DashType.label.copyWith(color: DashColors.accent)),
      _ => Text(value.toString(), style: DashType.body, overflow: TextOverflow.ellipsis),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          decoration: BoxDecoration(
            color: _hovering ? DashColors.hover : Colors.transparent,
            border: Border(bottom: BorderSide(color: DashColors.glassBorder.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              for (final col in widget.columns) Expanded(child: _cell(col)),
              SizedBox(
                width: 64,
                child: AnimatedOpacity(
                  duration: DashMotion.hover,
                  opacity: _hovering ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        iconSize: 16,
                        onPressed: widget.onOpen,
                        icon: const DashIcon('edit', size: 16, color: DashColors.text1),
                      ),
                      IconButton(
                        iconSize: 16,
                        onPressed: widget.onDelete,
                        icon: const DashIcon('delete', size: 16, color: DashColors.danger),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
