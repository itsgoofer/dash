import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';

/// New-database dialog, or — with [slug] — edits an existing schema in place
/// (name and fields; slug and folder stay stable so entry files never move).
Future<void> showSchemaEditor(BuildContext context, {String? slug}) {
  return showDialog(context: context, builder: (_) => _SchemaEditorDialog(slug: slug));
}

class _SchemaEditorDialog extends ConsumerStatefulWidget {
  const _SchemaEditorDialog({this.slug});
  final String? slug;

  @override
  ConsumerState<_SchemaEditorDialog> createState() => _SchemaEditorDialogState();
}

class _SchemaEditorDialogState extends ConsumerState<_SchemaEditorDialog> {
  late final TextEditingController _nameController;
  late final List<DbField> _fields;
  late final List<TextEditingController> _fieldNameControllers;
  bool get _editing => widget.slug != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.slug == null ? null : ref.read(dbSchemaProvider(widget.slug!));
    _nameController = TextEditingController(text: existing?.name ?? '');
    _fields = existing != null
        ? List.of(existing.fields)
        : [const DbField(name: 'title', type: FieldType.text, required: true)];
    _fieldNameControllers = [for (final f in _fields) TextEditingController(text: f.name)];
  }

  void _addField() {
    setState(() {
      _fields.add(const DbField(name: '', type: FieldType.text));
      _fieldNameControllers.add(TextEditingController());
    });
  }

  void _removeField(int i) {
    setState(() {
      _fields.removeAt(i);
      _fieldNameControllers.removeAt(i).dispose();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _fieldNameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final fields = _fields.where((f) => f.name.trim().isNotEmpty).toList();
    if (fields.isEmpty) return;

    final existing = _editing ? ref.read(dbSchemaProvider(widget.slug!)) : null;
    final slug = widget.slug ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final schema = DbSchema(name: name, folder: existing?.folder ?? 'Databases/$name', fields: fields);

    final root = ref.read(vaultPathProvider).value;
    if (root == null) return;
    await ref.read(vaultFsProvider).writeNote('$root/.dash/databases/$slug.yaml', schema.toYaml());

    if (!mounted) return;
    Navigator.pop(context);
    ref.read(databasesNavProvider.notifier).showTable(slug);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DashColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder)),
      title: Text(_editing ? 'Edit database' : 'New database', style: DashType.heading),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashTextField(controller: _nameController, hint: 'Database name', autofocus: true),
              const SizedBox(height: DashSpace.x3),
              Text('Fields', style: DashType.label),
              const SizedBox(height: DashSpace.x2),
              for (var i = 0; i < _fields.length; i++)
                _FieldRow(
                  field: _fields[i],
                  nameController: _fieldNameControllers[i],
                  onTypeChanged: (t) => setState(() => _fields[i] = _fields[i].copyWith(type: t)),
                  onNameChanged: (v) => _fields[i] = _fields[i].copyWith(name: v),
                  onOptionsChanged: (o) => setState(() => _fields[i] = _fields[i].copyWith(options: o)),
                  onRequiredChanged: (r) => setState(() => _fields[i] = _fields[i].copyWith(required: r)),
                  onRemove: _fields[i].name == 'title' ? null : () => _removeField(i),
                ),
              const SizedBox(height: DashSpace.x2),
              DashButton('Add field', icon: 'add', onTap: _addField),
            ],
          ),
        ),
      ),
      actions: [
        DashButton('Cancel', onTap: () => Navigator.pop(context)),
        DashButton(_editing ? 'Save' : 'Create', kind: DashButtonKind.primary, onTap: _save),
      ],
    );
  }
}

String _fieldTypeLabel(FieldType t) => switch (t) {
      FieldType.text => 'Text',
      FieldType.number => 'Number',
      FieldType.date => 'Date',
      FieldType.dynamicDate => 'Date (auto-today)',
      FieldType.checkbox => 'Boolean',
      FieldType.select => 'Select',
      FieldType.multiselect => 'Multi-select',
      FieldType.url => 'URL',
    };

extension on DbField {
  DbField copyWith({String? name, FieldType? type, List<String>? options, bool? required}) => DbField(
        name: name ?? this.name,
        type: type ?? this.type,
        required: required ?? this.required,
        min: min,
        max: max,
        options: options ?? this.options,
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.nameController,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onOptionsChanged,
    required this.onRequiredChanged,
    this.onRemove,
  });

  final DbField field;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<FieldType> onTypeChanged;
  final ValueChanged<List<String>> onOptionsChanged;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback? onRemove;

  bool get _hasOptions => field.type == FieldType.select || field.type == FieldType.multiselect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DashSpace.x2),
      padding: const EdgeInsets.all(DashSpace.x2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: DashRadius.br,
        border: Border.all(color: DashColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DashTextField(controller: nameController, hint: 'Field name', onChanged: onNameChanged),
              ),
              const SizedBox(width: DashSpace.x2),
              Expanded(
                child: DashDropdown<FieldType>(
                  value: field.type,
                  options: [for (final t in FieldType.values) DashOption(t, _fieldTypeLabel(t))],
                  onChanged: onTypeChanged,
                ),
              ),
              const SizedBox(width: DashSpace.x2),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onRequiredChanged(!field.required),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DashCheckbox(value: field.required, onChanged: onRequiredChanged),
                      const SizedBox(width: DashSpace.x1),
                      Text('Required', style: DashType.small),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: DashSpace.x1),
              SizedBox(
                width: DashSize.iconButton,
                child: onRemove == null ? null : DashIconBtn('close', onTap: onRemove),
              ),
            ],
          ),
          if (_hasOptions)
            Padding(
              padding: const EdgeInsets.only(top: DashSpace.x2),
              child: _OptionsEditor(options: field.options ?? const [], onChanged: onOptionsChanged),
            ),
        ],
      ),
    );
  }
}

/// Inline chip editor for a select/multiselect field's option list.
class _OptionsEditor extends StatefulWidget {
  const _OptionsEditor({required this.options, required this.onChanged});
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<_OptionsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final t = raw.trim();
    _controller.clear();
    if (t.isEmpty || widget.options.contains(t)) return;
    widget.onChanged([...widget.options, t]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DashSpace.x1,
      runSpacing: DashSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final o in widget.options)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onChanged(widget.options.where((x) => x != o).toList()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 3),
                decoration: BoxDecoration(
                  color: DashChip.optionColor(o).withValues(alpha: 0.15),
                  borderRadius: DashRadius.br,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o,
                        style: DashType.small.copyWith(color: DashChip.optionColor(o), fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    DashIcon('close', size: 12, color: DashChip.optionColor(o)),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          width: 120,
          height: DashSize.controlCompact,
          child: DashTextField(
            controller: _controller,
            hint: '+ option',
            height: DashSize.controlCompact,
            onSubmitted: _add,
          ),
        ),
      ],
    );
  }
}
