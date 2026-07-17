import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';

const _deepEq = DeepCollectionEquality();

/// Result of parsing a note: frontmatter data + raw body (untouched).
class ParsedNote {
  const ParsedNote(this.data, this.body);

  final Map<String, dynamic> data;
  final String body;
}

/// Frontmatter parse/serialize. Byte-stable: unchanged data → unchanged bytes.
abstract final class Frontmatter {
  /// Splits leading `---\n...\n---\n` YAML fence from [raw]. No fence → empty
  /// data, body is the whole (untouched) input.
  static ParsedNote parse(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty || lines[0].trim() != '---') {
      return ParsedNote(const {}, raw);
    }
    final closeIndex = lines.indexWhere((l) => l.trim() == '---', 1);
    if (closeIndex == -1) {
      return ParsedNote(const {}, raw);
    }
    final yamlText = lines.sublist(1, closeIndex).join('\n');
    final body = lines.sublist(closeIndex + 1).join('\n');
    final loaded = yamlText.trim().isEmpty ? null : loadYaml(yamlText);
    final data = _toPlain(loaded) as Map<String, dynamic>? ?? <String, dynamic>{};
    return ParsedNote(data, body);
  }

  /// Serializes [data] + [body] back to a full note string. Keys are written
  /// in [keyOrder] (only those present/non-null), then any remaining keys in
  /// their map insertion order. Null/absent fields are skipped.
  static String serialize(Map<String, dynamic> data, String body, {List<String>? keyOrder}) {
    final ordered = <String>[];
    for (final k in keyOrder ?? const <String>[]) {
      if (data.containsKey(k) && data[k] != null) ordered.add(k);
    }
    for (final k in data.keys) {
      if (!ordered.contains(k) && data[k] != null) ordered.add(k);
    }
    final buffer = StringBuffer('---\n');
    for (final key in ordered) {
      buffer.writeln('$key: ${_formatValue(data[key])}');
    }
    buffer.writeln('---');
    return '$buffer$body';
  }

  /// Rewrites [original] with [newData] if it differs semantically from the
  /// parsed frontmatter; otherwise returns [original] unchanged (byte-stable).
  static String updateFile(String original, Map<String, dynamic> newData, {List<String>? keyOrder}) {
    final parsed = parse(original);
    if (_deepEq.equals(parsed.data, newData)) return original;
    return serialize(newData, parsed.body, keyOrder: keyOrder ?? parsed.data.keys.toList());
  }

  static dynamic _toPlain(dynamic value) {
    if (value is YamlMap) {
      return <String, dynamic>{for (final e in value.entries) e.key.toString(): _toPlain(e.value)};
    }
    if (value is YamlList) return value.map(_toPlain).toList();
    return value;
  }

  static String _formatValue(dynamic value) {
    if (value is List) return '[${value.map(_formatScalar).join(', ')}]';
    return _formatScalar(value);
  }

  static String _formatScalar(dynamic value) {
    if (value is bool || value is num) return value.toString();
    return _quoteIfNeeded(value.toString());
  }

  static final _plainSafe = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9 ._/-]*[A-Za-z0-9._/-])?$');
  static const _reserved = {'true', 'false', 'null', '~', 'yes', 'no'};

  static String _quoteIfNeeded(String s) {
    if (s.isEmpty) return "''";
    final needsQuote =
        !_plainSafe.hasMatch(s) ||
        _reserved.contains(s.toLowerCase()) ||
        num.tryParse(s) != null;
    if (!needsQuote) return s;
    return "'${s.replaceAll("'", "''")}'";
  }
}
