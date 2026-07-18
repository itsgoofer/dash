String _yamlStr(String s) {
  final safe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]*$').hasMatch(s);
  return safe ? s : "'${s.replaceAll("'", "''")}'";
}

String _yamlNum(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

enum FieldType {
  text,
  number,
  date,
  dynamicDate,
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

  /// Flow-map yaml for one line of a schema's `fields:` list.
  String toYaml() {
    final b = StringBuffer('{name: ${_yamlStr(name)}, type: ${type.name}');
    if (required) b.write(', required: true');
    if (min != null) b.write(', min: ${_yamlNum(min!)}');
    if (max != null) b.write(', max: ${_yamlNum(max!)}');
    if (options != null) b.write(', options: [${options!.map(_yamlStr).join(', ')}]');
    b.write('}');
    return b.toString();
  }
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

  /// Serializes to `.dash/databases/<slug>.yaml` content.
  String toYaml() {
    final b = StringBuffer('name: ${_yamlStr(name)}\nfolder: ${_yamlStr(folder)}\nfields:\n');
    for (final f in fields) {
      b.writeln('  - ${f.toYaml()}');
    }
    return b.toString();
  }
}
