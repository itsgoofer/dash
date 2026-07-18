import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/properties_sidebar.dart';
import '../editor/editor.dart';
import 'db_widgets.dart';
import 'schema_ops.dart';

/// One database entry: typed field controls generated from the schema, plus
/// a free-form markdown body — mirrors JournalScreen's layout & autosave.
class EntryForm extends ConsumerWidget {
  const EntryForm({super.key, required this.slug, this.path});
  final String slug;
  final String? path;

  Future<void> _delete(BuildContext context, WidgetRef ref, String? title) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete entry?',
      message: 'This permanently deletes "${title ?? path}".',
    );
    if (!ok) return;
    final root = ref.read(vaultPathProvider).value;
    if (root == null || path == null) return;
    await ref.read(vaultFsProvider).deleteNote(p.join(root, path!));
    ref.read(databasesNavProvider.notifier).showTable(slug);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: slug, path: path);
    final schema = ref.watch(dbSchemaProvider(slug));
    final doc = ref.watch(dbEntryProvider(key));
    final notifier = ref.read(dbEntryProvider(key).notifier);
    if (schema == null) return const SizedBox.shrink();

    final title = doc.value?.fields['title'] as String?;

    final header = Row(
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
        if (path != null)
          DashButton(
            'Delete',
            icon: 'delete',
            kind: DashButtonKind.danger,
            onTap: () => _delete(context, ref, title),
          ),
      ],
    );
    final banner = doc.value?.changedOnDisk ?? false
        ? ChangedOnDiskBanner(onReload: notifier.reload, message: 'This entry changed on disk while you were editing.')
        : null;

    return switch (doc) {
      AsyncData(:final value) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  ?banner,
                  const SizedBox(height: DashSpace.x4),
                  Expanded(
                    child: NoteEditor(
                      key: ValueKey('$slug-$path'),
                      initialText: value.body,
                      onChanged: notifier.setBody,
                      centered: true,
                    ),
                  ),
                ],
              ),
            ),
            PropertiesSidebar(children: [
              for (final f in schema.fields)
                _FieldControl(
                  field: f,
                  value: value.fields[f.name],
                  onChanged: (v) => notifier.setField(f.name, v),
                  onAddOption: (o) => addSchemaOption(ref, slug, f.name, o),
                ),
            ]),
          ],
        ),
      AsyncError(:final error) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            ?banner,
            const SizedBox(height: DashSpace.x4),
            Expanded(child: Center(child: Text('$error', style: DashType.body.copyWith(color: DashColors.danger)))),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: DashSpace.x4),
            Expanded(child: Center(child: CircularProgressIndicator(color: DashColors.accent))),
          ],
        ),
    };
  }
}

class _FieldControl extends StatefulWidget {
  const _FieldControl({required this.field, required this.value, required this.onChanged, required this.onAddOption});
  final DbField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final ValueChanged<String> onAddOption;

  @override
  State<_FieldControl> createState() => _FieldControlState();
}

class _FieldControlState extends State<_FieldControl> {
  late final TextEditingController _controller = TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void didUpdateWidget(_FieldControl old) {
    super.didUpdateWidget(old);
    // Resync when the underlying value changes from outside (form reset / reload
    // from disk). The `!=` guard skips the echo of the user's own keystrokes.
    final v = widget.value?.toString() ?? '';
    if (v != _controller.text) _controller.text = v;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final options = f.options ?? const <String>[];
    Widget control;
    switch (f.type) {
      case FieldType.checkbox:
        control = SizedBox(
          height: DashSize.control,
          child: Align(
            alignment: Alignment.centerLeft,
            child: DashCheckbox(value: widget.value == true, onChanged: widget.onChanged),
          ),
        );
      case FieldType.select:
        control = DashDropdown<String>(
          value: widget.value as String?,
          options: [for (final o in options) DashOption(o, o, chipColor: DashChip.optionColor(o))],
          onChanged: widget.onChanged,
          onAddOption: (o) {
            widget.onAddOption(o);
            widget.onChanged(o);
          },
        );
      case FieldType.multiselect:
        final selected = (widget.value as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        control = DashMultiSelect(
          values: selected,
          options: [for (final o in options) DashOption(o, o, chipColor: DashChip.optionColor(o))],
          onChanged: widget.onChanged,
          onAddOption: (o) {
            widget.onAddOption(o);
            widget.onChanged([...selected, o]);
          },
        );
      case FieldType.date:
        control = DashDateField(value: widget.value?.toString(), onChanged: widget.onChanged);
      case FieldType.number:
        control = DashTextField(
          controller: _controller,
          numeric: true,
          onChanged: (v) => widget.onChanged(num.tryParse(v)),
        );
      case FieldType.url:
        control = DashTextField(controller: _controller, hint: 'https://…', onChanged: widget.onChanged);
      case FieldType.text:
        control = DashTextField(controller: _controller, onChanged: widget.onChanged);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(f.name, style: DashType.label), const SizedBox(height: 4), control],
    );
  }
}
