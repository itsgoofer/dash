/// Checklist parsing/editing over a note body's `- [ ]`/`- [x]` lines.
/// Toggling/appending are line-level string edits — never an AST rewrite —
/// so every other byte in the body is preserved untouched.
final _taskLine = RegExp(r'^(\s*-\s\[)([ xX])(\]\s+)(.*)$');

/// One checklist line, in document order. [lineIndex] is its index into
/// `body.split('\n')` — the key used by [toggleTask].
class TaskItem {
  const TaskItem({required this.lineIndex, required this.text, required this.checked});
  final int lineIndex;
  final String text;
  final bool checked;
}

/// Parses every task checklist line out of [body], in document order.
List<TaskItem> parseTasks(String body) {
  final lines = body.split('\n');
  final items = <TaskItem>[];
  for (var i = 0; i < lines.length; i++) {
    final m = _taskLine.firstMatch(lines[i]);
    if (m != null) items.add(TaskItem(lineIndex: i, text: m.group(4)!, checked: m.group(2)!.toLowerCase() == 'x'));
  }
  return items;
}

/// Flips the `[ ]`/`[x]` character pair on line [lineIndex] only; every other
/// byte in [body] is preserved.
String toggleTask(String body, int lineIndex) {
  final lines = body.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return body;
  final m = _taskLine.firstMatch(lines[lineIndex]);
  if (m == null) return body;
  final flipped = m.group(2)!.toLowerCase() == 'x' ? ' ' : 'x';
  lines[lineIndex] = '${m.group(1)}$flipped${m.group(3)}${m.group(4)}';
  return lines.join('\n');
}

/// Appends a new unchecked task as its own line at the end of [body].
String appendTask(String body, String text) {
  final t = text.trim();
  if (t.isEmpty) return body;
  final sep = body.isEmpty || body.endsWith('\n') ? '' : '\n';
  return '$body$sep- [ ] $t\n';
}

/// Cheap done/total count over a raw body string.
class TaskCounts {
  const TaskCounts(this.done, this.total);
  final int done;
  final int total;
  static const zero = TaskCounts(0, 0);

  factory TaskCounts.from(String body) {
    var done = 0, total = 0;
    for (final line in body.split('\n')) {
      final m = _taskLine.firstMatch(line);
      if (m == null) continue;
      total++;
      if (m.group(2)!.toLowerCase() == 'x') done++;
    }
    return TaskCounts(done, total);
  }
}
