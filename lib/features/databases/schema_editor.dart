import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';

/// Opens the "new database" dialog: name + field list, writes
/// `.dash/databases/<slug>.yaml` and jumps to the new (empty) table.
Future<void> showSchemaEditor(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _SchemaEditorDialog());
}

class _SchemaEditorDialog extends ConsumerStatefulWidget {
  const _SchemaEditorDialog();

  @override
  ConsumerState<_SchemaEditorDialog> createState() => _SchemaEditorDialogState();
}

class _SchemaEditorDialogState extends ConsumerState<_SchemaEditorDialog> {
  final _nameController = TextEditingController();
  final List<DbField> _fields = [const DbField(name: 'title', type: FieldType.text, required: true)];
  final List<TextEditingController> _fieldNameControllers = [TextEditingController(text: 'title')];

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

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final fields = _fields.where((f) => f.name.trim().isNotEmpty).toList();
    if (fields.isEmpty) return;
    final schema = DbSchema(name: name, folder: 'Databases/$name', fields: fields);

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
      title: const Text('New database', style: DashType.heading),
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
                  onRemove: i == 0 ? null : () => _removeField(i),
                ),
              const SizedBox(height: DashSpace.x2),
              DashButton('Add field', icon: 'add', onTap: _addField),
            ],
          ),
        ),
      ),
      actions: [
        DashButton('Cancel', onTap: () => Navigator.pop(context)),
        DashButton('Create', kind: DashButtonKind.primary, onTap: _create),
      ],
    );
  }
}

extension on DbField {
  DbField copyWith({String? name, FieldType? type, List<String>? options}) => DbField(
        name: name ?? this.name,
        type: type ?? this.type,
        required: this.required,
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
    this.onRemove,
  });

  final DbField field;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<FieldType> onTypeChanged;
  final ValueChanged<List<String>> onOptionsChanged;
  final VoidCallback? onRemove;

  bool get _hasOptions => field.type == FieldType.select || field.type == FieldType.multiselect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DashSpace.x2),
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
                  options: [for (final t in FieldType.values) DashOption(t, t.name)],
                  onChanged: onTypeChanged,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: DashSpace.x1),
                DashIconBtn('close', onTap: onRemove),
              ],
            ],
          ),
          if (_hasOptions)
            Padding(
              padding: const EdgeInsets.only(top: DashSpace.x1, left: DashSpace.x1),
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
