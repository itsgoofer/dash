import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';

/// Appends [option] to a select/multiselect field and rewrites the schema
/// yaml; the vault watcher re-indexes and every open view picks it up.
Future<void> addSchemaOption(WidgetRef ref, String slug, String fieldName, String option) async {
  final schema = ref.read(dbSchemaProvider(slug));
  final root = ref.read(vaultPathProvider).value;
  if (schema == null || root == null) return;
  final field = schema.fields.where((f) => f.name == fieldName).firstOrNull;
  if (field == null || (field.options?.contains(option) ?? false)) return;

  final fields = [
    for (final f in schema.fields)
      f.name == fieldName
          ? DbField(
              name: f.name,
              type: f.type,
              required: f.required,
              min: f.min,
              max: f.max,
              options: [...(f.options ?? const []), option],
            )
          : f,
  ];
  await ref.read(vaultFsProvider).writeNote(
        p.join(root, '.dash', 'databases', '$slug.yaml'),
        DbSchema(name: schema.name, folder: schema.folder, fields: fields).toYaml(),
      );
}
