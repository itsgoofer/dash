enum FieldType {
  text,
  number,
  date,
  checkbox,
  select,
  multiselect,
  url;

  static FieldType fromName(String? name) =>
      FieldType.values.firstWhere((f) => f.name == name, orElse: () => FieldType.text);
}

/// A single field definition inside a [DbSchema].
class DbField {
  const DbField({
    required this.name,
    required this.type,
    this.required = false,
    this.min,
    this.max,
    this.options,
  });

  factory DbField.fromYaml(Map yaml) => DbField(
    name: yaml['name'] as String,
    type: FieldType.fromName(yaml['type'] as String?),
    required: yaml['required'] as bool? ?? false,
    min: (yaml['min'] as num?)?.toDouble(),
    max: (yaml['max'] as num?)?.toDouble(),
    options: (yaml['options'] as List?)?.map((e) => e.toString()).toList(),
  );

  final String name;
  final FieldType type;
  final bool required;
  final double? min;
  final double? max;
  final List<String>? options;
}

/// User-defined database schema, loaded from `.dash/databases/<key>.yaml`.
class DbSchema {
  const DbSchema({required this.name, required this.folder, required this.fields});

  factory DbSchema.fromYaml(Map yaml) => DbSchema(
    name: yaml['name'] as String,
    folder: yaml['folder'] as String,
    fields: ((yaml['fields'] as List?) ?? const [])
        .map((f) => DbField.fromYaml(f as Map))
        .toList(),
  );

  final String name;
  final String folder;
  final List<DbField> fields;
}
