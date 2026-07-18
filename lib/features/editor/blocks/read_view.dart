import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/tasks.dart';
import '../../../theme/dash_theme.dart';

/// Obsidian-like *read* view: renders a note body as styled document widgets —
/// headings, real bold/italic, inline code, links, blockquotes, `> [!note]`
/// callouts, fenced code blocks, images (resolved against the vault), and
/// interactive task checkboxes (toggled via line-mapped string edits, so the
/// text stays byte-authoritative). Never mutates the body except through the
/// task toggle, which routes back out via [onChanged].
class MarkdownReadView extends StatelessWidget {
  const MarkdownReadView({
    super.key,
    required this.body,
    required this.vaultRoot,
    required this.onChanged,
    this.centered = true,
  });

  final String body;
  final String vaultRoot;
  final ValueChanged<String> onChanged;
  final bool centered;

  static final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final _task = RegExp(r'^(\s*)- \[([ xX])\]\s+(.*)$');
  static final _bullet = RegExp(r'^(\s*)[-*]\s+(.*)$');
  static final _image = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$');
  static final _callout = RegExp(r'^>\s*\[!(\w+)\]\s*(.*)$');
  static final _hr = RegExp(r'^(---+|\*\*\*+|___+)\s*$');

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final blocks = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Fenced code block.
      if (line.trimLeft().startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++; // closing fence
        blocks.add(_codeBlock(buf.join('\n')));
        continue;
      }

      // Callout `> [!type] title` + following `>` lines.
      final callout = _callout.firstMatch(line);
      if (callout != null) {
        final inner = <String>[];
        if (callout.group(2)!.trim().isNotEmpty) inner.add(callout.group(2)!.trim());
        i++;
        while (i < lines.length && lines[i].startsWith('>')) {
          inner.add(lines[i].replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_calloutBox(callout.group(1)!, inner.join('\n')));
        continue;
      }

      // Plain blockquote.
      if (line.startsWith('>')) {
        final inner = <String>[];
        while (i < lines.length && lines[i].startsWith('>')) {
          inner.add(lines[i].replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_quote(inner.join('\n')));
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final style = switch (level) { 1 => DashType.editorH1, 2 => DashType.editorH2, _ => DashType.editorH3 };
        blocks.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? DashSpace.x4 : DashSpace.x3, bottom: DashSpace.x1),
          child: Text.rich(TextSpan(children: _inline(heading.group(2)!, style)), style: style),
        ));
        i++;
        continue;
      }

      final task = _task.firstMatch(line);
      if (task != null) {
        blocks.add(_taskRow(i, task.group(2)!.toLowerCase() == 'x', task.group(3)!));
        i++;
        continue;
      }

      final image = _image.firstMatch(line);
      if (image != null) {
        blocks.add(_imageBlock(image.group(2)!));
        i++;
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(_bulletRow(bullet.group(2)!));
        i++;
        continue;
      }

      if (_hr.hasMatch(line)) {
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: DashSpace.x3),
          child: Divider(color: DashColors.glassBorder, height: 1),
        ));
        i++;
        continue;
      }

      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: DashSpace.x2));
        i++;
        continue;
      }

      blocks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(TextSpan(children: _inline(line, DashType.body)), style: DashType.body),
      ));
      i++;
    }

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: DashSpace.x2),
      child: Align(
        alignment: centered ? Alignment.topCenter : Alignment.topLeft,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content),
      ),
    );
  }

  // ── Blocks ──────────────────────────────────────────────────────────────

  Widget _taskRow(int lineIndex, bool checked, String text) {
    return InkWell(
      onTap: () => onChanged(toggleTask(body, lineIndex)),
      borderRadius: DashRadius.br,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, height: 24, child: Checkbox(value: checked, onChanged: (_) => onChanged(toggleTask(body, lineIndex)), activeColor: DashColors.accent)),
          const SizedBox(width: DashSpace.x1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(children: _inline(text, DashType.body.copyWith(
                  color: checked ? DashColors.text2 : DashColors.text0,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bulletRow(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 9, left: DashSpace.x2, right: DashSpace.x2),
            child: SizedBox(width: 5, height: 5, child: DecoratedBox(decoration: BoxDecoration(color: DashColors.text1, shape: BoxShape.circle))),
          ),
          Expanded(child: Text.rich(TextSpan(children: _inline(text, DashType.body)), style: DashType.body)),
        ]),
      );

  Widget _quote(String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: DashSpace.x1),
        padding: const EdgeInsets.only(left: DashSpace.x3),
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: DashColors.text2, width: 3))),
        child: Text.rich(TextSpan(children: _inline(text, DashType.body.copyWith(color: DashColors.text1, fontStyle: FontStyle.italic))), style: DashType.body),
      );

  Widget _calloutBox(String type, String text) {
    final color = switch (type.toLowerCase()) {
      'warning' || 'caution' || 'attention' => DashColors.warning,
      'danger' || 'error' || 'bug' || 'fail' => DashColors.danger,
      'success' || 'check' || 'done' || 'tip' => DashColors.success,
      _ => DashColors.accent,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DashSpace.x2),
      padding: const EdgeInsets.all(DashSpace.x3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: DashRadius.br,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(type.toUpperCase(), style: DashType.small.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: DashSpace.x1),
          Text.rich(TextSpan(children: _inline(text, DashType.body)), style: DashType.body),
        ],
      ]),
    );
  }

  Widget _codeBlock(String code) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: DashSpace.x2),
        padding: const EdgeInsets.all(DashSpace.x3),
        decoration: BoxDecoration(color: DashColors.bg1, borderRadius: DashRadius.br, border: Border.all(color: DashColors.glassBorder)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(code, style: DashType.mono.copyWith(color: DashColors.text1, height: 1.5)),
        ),
      );

  Widget _imageBlock(String relPath) {
    final file = File(p.join(vaultRoot, relPath));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DashSpace.x2),
      child: ClipRRect(
        borderRadius: DashRadius.br,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            padding: const EdgeInsets.all(DashSpace.x3),
            decoration: BoxDecoration(color: DashColors.bg1, borderRadius: DashRadius.br, border: Border.all(color: DashColors.glassBorder)),
            child: Text('Missing image: $relPath', style: DashType.small.copyWith(color: DashColors.text2)),
          ),
        ),
      ),
    );
  }

  /// Mid-paragraph `![alt](path)` — a real image constrained to the reading
  /// measure, 4px radius (standalone image lines still use [_imageBlock]).
  Widget _inlineImage(String relPath) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 260),
        child: ClipRRect(
          borderRadius: DashRadius.br,
          child: Image.file(
            File(p.join(vaultRoot, relPath)),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text('Missing image: $relPath', style: DashType.small.copyWith(color: DashColors.text2)),
          ),
        ),
      );

  // ── Inline ──────────────────────────────────────────────────────────────

  static final _inlineRe = RegExp(
    r'(`[^`]+`)'
    r'|(!\[[^\]]*\]\([^)]*\))'
    r'|(\[[^\]]*\]\([^)]*\))'
    r'|(\*\*[^*]+\*\*)'
    r'|(~~[^~]+~~)'
    r'|(<u>[^<]+</u>)'
    r'|(\*[^*\n]+\*)',
  );
  static final _linkRe = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');

  List<InlineSpan> _inline(String text, TextStyle base) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start), style: base));
      final s = m.group(0)!;
      if (m.group(1) != null) {
        out.add(TextSpan(text: s.substring(1, s.length - 1), style: base.copyWith(fontFamily: DashType.codeFamily, fontSize: 13, color: DashColors.text0, background: Paint()..color = DashColors.bg1)));
      } else if (m.group(2) != null) {
        final im = _linkRe.firstMatch(s)!;
        out.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: _inlineImage(im.group(2)!)));
      } else if (m.group(3) != null) {
        final l = _linkRe.firstMatch(s)!;
        out.add(TextSpan(text: l.group(1), style: base.copyWith(color: DashColors.accent)));
      } else if (m.group(4) != null) {
        out.add(TextSpan(text: s.substring(2, s.length - 2), style: base.copyWith(fontWeight: FontWeight.w700, color: base.color == DashColors.text2 ? base.color : DashColors.text0)));
      } else if (m.group(5) != null) {
        out.add(TextSpan(text: s.substring(2, s.length - 2), style: base.copyWith(decoration: TextDecoration.lineThrough, color: DashColors.text1)));
      } else if (m.group(6) != null) {
        out.add(TextSpan(text: s.substring(3, s.length - 4), style: base.copyWith(decoration: TextDecoration.underline)));
      } else {
        out.add(TextSpan(text: s.substring(1, s.length - 1), style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last), style: base));
    return out;
  }
}
