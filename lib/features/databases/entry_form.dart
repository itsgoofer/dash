import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/glass_panel.dart';
import '../editor/editor.dart';
import 'db_widgets.dart';

/// One database entry: typed field controls generated from the schema, plus
/// a free-form markdown body — mirrors JournalScreen's layout & autosave.
class EntryForm extends ConsumerWidget {
  const EntryForm({super.key, required this.slug, this.path});
  final String slug;
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: slug, path: path);
    final schema = ref.watch(dbSchemaProvider(slug));
    final doc = ref.watch(dbEntryProvider(key));
    final notifier = ref.read(dbEntryProvider(key).notifier);
    if (schema == null) return const SizedBox.shrink();

    final title = doc.value?.fields['title'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackNavButton(onTap: () => ref.read(databasesNavProvider.notifier).showTable(slug)),
            const SizedBox(width: DashSpace.x2),
            Expanded(
              child: Text(
                (title == null || title.isEmpty) ? 'New entry' : title,
                style: DashType.display,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (doc.value?.changedOnDisk ?? false)
          ChangedOnDiskBanner(onReload: notifier.reload, message: 'This entry changed on disk while you were editing.'),
        const SizedBox(height: DashSpace.x4),
        switch (doc) {
          AsyncData(:final value) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldsPanel(schema: schema, fields: value.fields, onChanged: notifier.setField),
                  const SizedBox(height: DashSpace.x4),
                  Expanded(
                    child: NoteEditor(
                      key: ValueKey('$slug-$path'),
                      initialText: value.body,
                      onChanged: notifier.setBody,
                      centered: false,
                    ),
                  ),
                ],
              ),
            ),
          AsyncError(:final error) => Expanded(
              child: Center(child: Text('$error', style: DashType.body.copyWith(color: DashColors.danger))),
            ),
          _ => const Expanded(child: Center(child: CircularProgressIndicator(color: DashColors.accent))),
        },
      ],
    );
  }
}

class _FieldsPanel extends StatelessWidget {
  const _FieldsPanel({required this.schema, required this.fields, required this.onChanged});
  final DbSchema schema;
  final Map<String, dynamic> fields;
  final void Function(String, dynamic) onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Wrap(
        spacing: DashSpace.x3,
        runSpacing: DashSpace.x3,
        children: [
          for (final f in schema.fields)
            SizedBox(
              width: 220,
              child: _FieldControl(field: f, value: fields[f.name], onChanged: (v) => onChanged(f.name, v)),
            ),
        ],
      ),
    );
  }
}

class _FieldControl extends StatefulWidget {
  const _FieldControl({required this.field, required this.value, required this.onChanged});
  final DbField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_FieldControl> createState() => _FieldControlState();
}

class _FieldControlState extends State<_FieldControl> {
  late final TextEditingController _controller = TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final label = Text(f.name, style: DashType.label);
    Widget control;
    switch (f.type) {
      case FieldType.checkbox:
        control = Checkbox(
          value: widget.value == true,
          onChanged: (v) => widget.onChanged(v ?? false),
          activeColor: DashColors.accent,
        );
      case FieldType.select:
        control = DropdownButtonFormField<String>(
          initialValue: widget.value as String?,
          items: [for (final o in f.options ?? const <String>[]) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: widget.onChanged,
          dropdownColor: DashColors.bg1,
        );
      case FieldType.multiselect:
        final selected = (widget.value as List?)?.map((e) => e.toString()).toSet() ?? const <String>{};
        control = Wrap(
          spacing: DashSpace.x1,
          children: [
            for (final o in f.options ?? const <String>[])
              FilterChip(
                label: Text(o, style: DashType.small),
                selected: selected.contains(o),
                onSelected: (sel) {
                  final next = Set<String>.of(selected);
                  sel ? next.add(o) : next.remove(o);
                  widget.onChanged(next.toList());
                },
              ),
          ],
        );
      case FieldType.date:
        control = TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          decoration: const InputDecoration(hintText: 'yyyy-mm-dd'),
        );
      case FieldType.number:
        control = TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => widget.onChanged(num.tryParse(v)),
        );
      case FieldType.url:
      case FieldType.text:
        control = TextField(controller: _controller, onChanged: widget.onChanged);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, const SizedBox(height: 4), control]);
  }
}
