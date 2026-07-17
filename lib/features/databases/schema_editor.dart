import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
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
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Database name')),
              const SizedBox(height: DashSpace.x3),
              Text('Fields', style: DashType.label),
              const SizedBox(height: DashSpace.x2),
              for (var i = 0; i < _fields.length; i++)
                _FieldRow(
                  field: _fields[i],
                  nameController: _fieldNameControllers[i],
                  onTypeChanged: (t) => setState(() => _fields[i] = _fields[i].copyWith(type: t)),
                  onNameChanged: (v) => _fields[i] = _fields[i].copyWith(name: v),
                  onRemove: i == 0 ? null : () => _removeField(i),
                ),
              const SizedBox(height: DashSpace.x2),
              TextButton.icon(
                onPressed: _addField,
                icon: const DashIcon('add', size: 16, color: DashColors.text1),
                label: const Text('Add field'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }
}

extension on DbField {
  DbField copyWith({String? name, FieldType? type}) => DbField(
        name: name ?? this.name,
        type: type ?? this.type,
        required: this.required,
        min: min,
        max: max,
        options: options,
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.nameController,
    required this.onNameChanged,
    required this.onTypeChanged,
    this.onRemove,
  });

  final DbField field;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<FieldType> onTypeChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DashSpace.x2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Field name'),
              onChanged: onNameChanged,
            ),
          ),
          const SizedBox(width: DashSpace.x2),
          Expanded(
            child: DropdownButtonFormField<FieldType>(
              initialValue: field.type,
              items: [for (final t in FieldType.values) DropdownMenuItem(value: t, child: Text(t.name))],
              onChanged: (t) {
                if (t != null) onTypeChanged(t);
              },
              dropdownColor: DashColors.bg1,
            ),
          ),
          if (onRemove != null)
            IconButton(onPressed: onRemove, icon: const DashIcon('close', size: 16, color: DashColors.text1)),
        ],
      ),
    );
  }
}
