import 'dart:math' as math;

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
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/empty_state.dart';
import 'db_widgets.dart';
import 'schema_editor.dart';

const _actionsWidth = 60.0;
const _minColWidth = 80.0;
const _maxColWidth = 600.0;

/// Per-database view prefs (column order, widths, hidden set) — session-scoped.
class _ViewState {
  const _ViewState({this.order = const [], this.widths = const {}, this.hidden = const {}});
  final List<String> order;
  final Map<String, double> widths;
  final Set<String> hidden;

  _ViewState copyWith({List<String>? order, Map<String, double>? widths, Set<String>? hidden}) =>
      _ViewState(order: order ?? this.order, widths: widths ?? this.widths, hidden: hidden ?? this.hidden);
}

class _ViewStateNotifier extends Notifier<_ViewState> {
  _ViewStateNotifier(this.slug);
  final String slug;

  @override
  _ViewState build() => const _ViewState();
  void set(_ViewState s) => state = s;
}

final _viewStateProvider =
    NotifierProvider.family<_ViewStateNotifier, _ViewState, String>(_ViewStateNotifier.new);

/// Sortable, searchable, column-configurable table of one database's entries.
class DbTableScreen extends ConsumerStatefulWidget {
  const DbTableScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<DbTableScreen> createState() => _DbTableScreenState();
}

class _DbTableScreenState extends ConsumerState<DbTableScreen> {
  String _sortCol = '';
  bool _asc = true;
  String _query = '';

  dynamic _valueOf(NoteMeta m, String col) => m.frontmatter[col];

  /// Saved order first (columns that still exist), then any new schema columns.
  List<String> _orderedColumns(List<String> schemaCols, _ViewState vs) => [
        ...vs.order.where(schemaCols.contains),
        ...schemaCols.where((c) => !vs.order.contains(c)),
      ];

  bool _matches(NoteMeta row, List<String> cols) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return cols.any((c) {
      final v = row.frontmatter[c];
      return v != null && v.toString().toLowerCase().contains(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final schema = ref.watch(dbSchemaProvider(widget.slug));
    if (schema == null) return const SizedBox.shrink();

    final vs = ref.watch(_viewStateProvider(widget.slug));
    final vsNotifier = ref.read(_viewStateProvider(widget.slug).notifier);
    final allColumns = _orderedColumns([for (final f in schema.fields) f.name], vs);
    final columns = [for (final c in allColumns) if (!vs.hidden.contains(c)) c];

    final rows = ref.watch(dbRowsProvider(widget.slug)).where((r) => _matches(r, columns)).toList();
    final sortCol = columns.contains(_sortCol) ? _sortCol : (columns.firstOrNull ?? '');
    if (sortCol.isNotEmpty) {
      rows.sort((a, b) {
        final cmp = Comparable.compare(
            _valueOf(a, sortCol)?.toString() ?? '', _valueOf(b, sortCol)?.toString() ?? '');
        return _asc ? cmp : -cmp;
      });
    }

    double widthOf(String c) => vs.widths[c] ?? (c == 'title' ? 240 : 150);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackNavButton(onTap: () => ref.read(databasesNavProvider.notifier).showList()),
            const SizedBox(width: DashSpace.x2),
            Text(schema.name, style: DashType.display),
            const Spacer(),
            SizedBox(
              width: 220,
              child: DashTextField(
                icon: 'search',
                hint: 'Search entries…',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: DashSpace.x2),
            _ColumnsButton(
              columns: allColumns,
              hidden: vs.hidden,
              onToggle: (c) {
                final next = Set<String>.of(vs.hidden);
                if (!next.remove(c)) {
                  if (allColumns.length - next.length <= 1) return; // keep at least one visible
                  next.add(c);
                }
                vsNotifier.set(vs.copyWith(hidden: next));
              },
            ),
            const SizedBox(width: DashSpace.x2),
            DashIconBtn('settings',
                tooltip: 'Edit database', onTap: () => showSchemaEditor(context, slug: widget.slug)),
            const SizedBox(width: DashSpace.x2),
            DashButton(
              'New entry',
              icon: 'add',
              kind: DashButtonKind.primary,
              onTap: () => ref.read(databasesNavProvider.notifier).showEntry(widget.slug),
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x3),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  icon: _query.isEmpty ? 'database' : 'search',
                  message: _query.isEmpty ? 'No entries yet.' : 'No entries match "$_query".')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final total = columns.fold(0.0, (s, c) => s + widthOf(c)) + _actionsWidth;
                    final tableWidth = math.max(total, constraints.maxWidth);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeaderRow(
                              columns: columns,
                              widthOf: widthOf,
                              sortCol: sortCol,
                              asc: _asc,
                              onSort: (c) => setState(() {
                                if (_sortCol == c) {
                                  _asc = !_asc;
                                } else {
                                  _sortCol = c;
                                  _asc = true;
                                }
                              }),
                              onResize: (c, delta) {
                                final widths = Map<String, double>.of(vs.widths);
                                widths[c] = (widthOf(c) + delta).clamp(_minColWidth, _maxColWidth);
                                vsNotifier.set(vs.copyWith(widths: widths));
                              },
                              onReorder: (dragged, target) {
                                final order = List<String>.of(allColumns)..remove(dragged);
                                order.insert(order.indexOf(target).clamp(0, order.length), dragged);
                                vsNotifier.set(vs.copyWith(order: order));
                              },
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, i) => _EntryRow(
                                  row: rows[i],
                                  columns: columns,
                                  widthOf: widthOf,
                                  schema: schema,
                                  onOpen: () => ref
                                      .read(databasesNavProvider.notifier)
                                      .showEntry(widget.slug, path: rows[i].path),
                                  onDelete: () async {
                                    final ok = await showConfirmDialog(
                                      context,
                                      title: 'Delete entry?',
                                      message:
                                          'This permanently deletes "${rows[i].frontmatter['title'] ?? rows[i].path}".',
                                    );
                                    if (!ok) return;
                                    final root = ref.read(vaultPathProvider).value;
                                    if (root == null) return;
                                    await ref.read(vaultFsProvider).deleteNote(p.join(root, rows[i].path));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// "Columns" toolbar dropdown: visibility toggles for every column.
class _ColumnsButton extends StatelessWidget {
  const _ColumnsButton({required this.columns, required this.hidden, required this.onToggle});
  final List<String> columns;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return DashMenuAnchor(
      menuWidth: 200,
      triggerBuilder: (context, open, hovering) => AnimatedContainer(
        duration: DashMotion.hover,
        height: DashSize.control,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: (open || hovering) ? DashColors.hover : Colors.transparent,
          borderRadius: DashRadius.br,
          border: Border.all(color: DashColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DashIcon('visibility', size: 14, color: open ? DashColors.accent : DashColors.text1),
            const SizedBox(width: 6),
            Text('Columns',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (open || hovering) ? DashColors.text0 : DashColors.text1)),
          ],
        ),
      ),
      itemCount: columns.length,
      itemBuilder: (context, i, close) {
        final c = columns[i];
        final visible = !hidden.contains(c);
        return SizedBox(
          height: 28,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
                child: Row(
                  children: [
                    DashCheckbox(value: visible, onChanged: (_) => onToggle(c)),
                    const SizedBox(width: DashSpace.x2),
                    Expanded(
                        child: Text(c,
                            style: const TextStyle(
                                fontFamily: 'Inter', fontSize: 13, color: DashColors.text0),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.widthOf,
    required this.sortCol,
    required this.asc,
    required this.onSort,
    required this.onResize,
    required this.onReorder,
  });

  final List<String> columns;
  final double Function(String) widthOf;
  final String sortCol;
  final bool asc;
  final ValueChanged<String> onSort;
  final void Function(String col, double delta) onResize;
  final void Function(String dragged, String target) onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(bottom: BorderSide(color: DashColors.glassBorder)),
      ),
      child: Row(
        children: [
          for (final c in columns)
            SizedBox(
              width: widthOf(c),
              child: _HeaderCell(
                name: c,
                sorted: sortCol == c,
                asc: asc,
                onSort: () => onSort(c),
                onResize: (d) => onResize(c, d),
                onReorder: (dragged) => onReorder(dragged, c),
              ),
            ),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    required this.name,
    required this.sorted,
    required this.asc,
    required this.onSort,
    required this.onResize,
    required this.onReorder,
  });

  final String name;
  final bool sorted;
  final bool asc;
  final VoidCallback onSort;
  final ValueChanged<double> onResize;
  final ValueChanged<String> onReorder;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(widget.name,
              style: DashType.heading.copyWith(fontSize: 12, color: widget.sorted ? DashColors.text0 : DashColors.text1),
              overflow: TextOverflow.ellipsis),
        ),
        if (widget.sorted) ...[
          const SizedBox(width: DashSpace.x1),
          DashIcon(widget.asc ? 'arrow_upward' : 'arrow_downward', size: 12, color: DashColors.accent),
        ],
      ],
    );

    return Row(
      children: [
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (d) {
              final ok = d.data != widget.name;
              if (ok) setState(() => _dragOver = true);
              return ok;
            },
            onLeave: (_) => setState(() => _dragOver = false),
            onAcceptWithDetails: (d) {
              setState(() => _dragOver = false);
              widget.onReorder(d.data);
            },
            builder: (context, candidates, rejected) => Draggable<String>(
              data: widget.name,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11141C),
                    borderRadius: DashRadius.br,
                    border: Border.all(color: DashColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(widget.name, style: DashType.heading.copyWith(fontSize: 12)),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: _cellBody(label)),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: widget.onSort, behavior: HitTestBehavior.opaque, child: _cellBody(label)),
              ),
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => widget.onResize(d.delta.dx),
            child: Container(
              width: 8,
              alignment: Alignment.center,
              child: Container(width: 1, height: 16, color: DashColors.glassBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cellBody(Widget label) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
        alignment: Alignment.centerLeft,
        color: _dragOver ? DashColors.accentDim : Colors.transparent,
        child: label,
      );
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.row,
    required this.columns,
    required this.widthOf,
    required this.schema,
    required this.onOpen,
    required this.onDelete,
  });

  final NoteMeta row;
  final List<String> columns;
  final double Function(String) widthOf;
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
      FieldType.number => Text(value.toString(), style: DashType.mono.copyWith(fontSize: 11.5)),
      FieldType.checkbox => Align(
          alignment: Alignment.centerLeft,
          child: value == true ? DashIcon('check', size: 14, color: DashColors.accent) : const SizedBox.shrink(),
        ),
      FieldType.select => Align(
          alignment: Alignment.centerLeft,
          child: DashChip(value.toString(), color: DashChip.optionColor(value.toString())),
        ),
      FieldType.multiselect => Wrap(
          spacing: 4,
          children: [
            for (final v in (value as List)) DashChip(v.toString(), color: DashChip.optionColor(v.toString()))
          ],
        ),
      FieldType.date => Text(value.toString(), style: DashType.small),
      FieldType.url =>
        Text(value.toString(), style: DashType.small.copyWith(color: DashColors.accent), overflow: TextOverflow.ellipsis),
      _ => Text(value.toString(),
          style: DashType.body.copyWith(fontSize: 13, height: 1.2), overflow: TextOverflow.ellipsis),
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
          height: 34,
          decoration: BoxDecoration(
            color: _hovering ? DashColors.hover : Colors.transparent,
            border: Border(bottom: BorderSide(color: DashColors.glassBorder.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              for (final col in widget.columns)
                SizedBox(
                  width: widget.widthOf(col),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
                    child: Align(alignment: Alignment.centerLeft, child: _cell(col)),
                  ),
                ),
              SizedBox(
                width: _actionsWidth,
                child: Visibility(
                  visible: _hovering,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DashIconBtn('edit', size: 14, onTap: widget.onOpen),
                      DashIconBtn('delete', size: 14, color: DashColors.danger, onTap: widget.onDelete),
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
