import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../theme/dash_theme.dart';

/// Stage A source-first editor: a [TextEditingController] that styles the
/// markdown source *as a document* without ever altering the text — headings
/// at display sizes, real bold/italic, dimmed syntax markers, styled tasks and
/// links. The parser is line-based with simple inline regexes, recomputed per
/// [buildTextSpan] (documents are personal-scale).
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  /// Vault root for resolving `![alt](rel/path)` images; set by the editor.
  String vaultRoot = '';

  static final _heading = RegExp(r'^(#{1,3}) ');
  static final _task = RegExp(r'^(\s*- \[[ xX]\] )');
  static final _quote = RegExp(r'^(>+ ?)');
  static final _link = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
  static final _inline = RegExp(
    r'(`[^`]+`)' // 1 code
    r'|(!\[[^\]]*\]\([^)]*\))' // 2 image
    r'|(\[[^\]]*\]\([^)]*\))' // 3 link
    r'|(\*\*[^*]+\*\*)' // 4 bold
    r'|(~~[^~]+~~)' // 5 strike
    r'|(<u>[^<]+</u>)' // 6 underline
    r'|(\*[^*\n]+\*)', // 7 italic
  );

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? DashType.body;
    // Cursor-aware markers: dimmed (text2) on the line(s) the selection touches,
    // collapsed to ~zero width (transparent + fontSize 1) everywhere else, so
    // "## Title" reads as "Title" flush to the line start when inactive. Clicking
    // a line re-activates it and the markers spring back to editable size — the
    // same collapse trick already used for inactive inline images. Text is never
    // mutated.
    final dimmed = base.copyWith(color: DashColors.text2, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal);
    final hidden = dimmed.copyWith(color: const Color(0x00000000), fontSize: 1, letterSpacing: 0);
    final codeBlock = base.copyWith(fontFamily: DashType.codeFamily, fontSize: 13, color: DashColors.text1, height: 1.5);

    final sel = selection;
    final children = <InlineSpan>[];
    final lines = text.split('\n');
    var inFence = false;
    var offset = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = offset;
      final lineEnd = offset + line.length;
      final active = sel.isValid && sel.end >= lineStart && sel.start <= lineEnd;
      final marker = active ? dimmed : hidden;
      final isFence = line.trimLeft().startsWith('```');

      if (isFence || inFence) {
        children.add(TextSpan(text: line, style: codeBlock));
        if (isFence) inFence = !inFence;
      } else {
        _styleLine(line, base, marker, active, children);
      }
      if (i != lines.length - 1) children.add(TextSpan(text: '\n', style: base));
      offset = lineEnd + 1;
    }
    return TextSpan(style: base, children: children);
  }

  void _styleLine(String line, TextStyle base, TextStyle marker, bool active, List<InlineSpan> out) {
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final hStyle = switch (level) { 1 => DashType.editorH1, 2 => DashType.editorH2, _ => DashType.editorH3 };
      // Active: `# ` shown dimmed at heading size. Inactive: `marker` is already
      // collapsed (fontSize 1) so the title sits flush at the line start.
      final mk = active ? marker.merge(hStyle).copyWith(color: marker.color) : marker;
      out.add(TextSpan(text: line.substring(0, heading.end), style: mk));
      out.add(TextSpan(text: line.substring(heading.end), style: hStyle));
      return;
    }

    final task = _task.firstMatch(line);
    if (task != null) {
      final checked = line[task.end - 3] == 'x' || line[task.end - 3] == 'X';
      out.add(TextSpan(text: line.substring(0, task.end), style: marker));
      final body = checked
          ? base.copyWith(color: DashColors.text1, decoration: TextDecoration.lineThrough)
          : base;
      _inlineSpans(line.substring(task.end), body, marker, active, out);
      return;
    }

    final quote = _quote.firstMatch(line);
    if (quote != null) {
      out.add(TextSpan(text: line.substring(0, quote.end), style: marker));
      _inlineSpans(line.substring(quote.end), base.copyWith(color: DashColors.text0, fontStyle: FontStyle.italic), marker, active, out);
      return;
    }

    _inlineSpans(line, base, marker, active, out);
  }

  /// Emits inline-styled spans for [text], reconstructing every character
  /// exactly (markers dimmed, content styled).
  void _inlineSpans(String text, TextStyle base, TextStyle marker, bool active, List<InlineSpan> out) {
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start), style: base));
      final s = m.group(0)!;
      if (m.group(1) != null) {
        final inner = s.substring(1, s.length - 1);
        out.add(TextSpan(text: '`', style: marker));
        out.add(TextSpan(text: inner, style: base.copyWith(fontFamily: DashType.codeFamily, fontSize: 13, color: DashColors.text0, background: Paint()..color = DashColors.bg1)));
        out.add(TextSpan(text: '`', style: marker));
      } else if (m.group(2) != null) {
        _imageSpans(s, base, marker, active, out);
      } else if (m.group(3) != null) {
        final l = _link.firstMatch(s)!;
        out.add(TextSpan(text: '[', style: marker));
        out.add(TextSpan(text: l.group(1), style: base.copyWith(color: DashColors.accent)));
        out.add(TextSpan(text: '](${l.group(2)})', style: marker));
      } else if (m.group(4) != null) {
        _wrap(s, 2, base.copyWith(fontWeight: FontWeight.w700, color: DashColors.text0), marker, out);
      } else if (m.group(5) != null) {
        _wrap(s, 2, base.copyWith(decoration: TextDecoration.lineThrough, color: DashColors.text1), marker, out);
      } else if (m.group(6) != null) {
        out.add(TextSpan(text: '<u>', style: marker));
        out.add(TextSpan(text: s.substring(3, s.length - 4), style: base.copyWith(decoration: TextDecoration.underline, color: DashColors.text0)));
        out.add(TextSpan(text: '</u>', style: marker));
      } else {
        _wrap(s, 1, base.copyWith(fontStyle: FontStyle.italic), marker, out);
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last), style: base));
  }

  /// `![alt](path)` — on the active line the syntax shows (dimmed markers,
  /// accent alt text) for editing; on inactive lines the syntax collapses to
  /// near-zero width and the actual image renders in place of the final `)`
  /// (a WidgetSpan occupies exactly one character position, so caret/click
  /// mapping stays consistent with the underlying text).
  void _imageSpans(String s, TextStyle base, TextStyle marker, bool active, List<InlineSpan> out) {
    final m = _link.firstMatch(s)!;
    final path = m.group(2)!;
    if (active) {
      out.add(TextSpan(text: '![', style: marker));
      out.add(TextSpan(text: m.group(1), style: base.copyWith(color: DashColors.accent)));
      out.add(TextSpan(text: ']($path)', style: marker));
      return;
    }
    out.add(TextSpan(text: s.substring(0, s.length - 1), style: marker.copyWith(fontSize: 1, letterSpacing: 0)));
    out.add(WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DashSpace.x1),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 180),
          child: ClipRRect(
            borderRadius: DashRadius.br,
            child: Image.file(
              File(p.isAbsolute(path) ? path : p.join(vaultRoot, path)),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: DashSpace.x1),
                decoration: BoxDecoration(color: DashColors.bg1, borderRadius: DashRadius.br, border: Border.all(color: DashColors.glassBorder)),
                child: Text('Missing image: $path', style: DashType.small.copyWith(color: DashColors.text2)),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  /// Dimmed marker of width [n] on each side, styled content between.
  void _wrap(String s, int n, TextStyle content, TextStyle marker, List<InlineSpan> out) {
    out.add(TextSpan(text: s.substring(0, n), style: marker));
    out.add(TextSpan(text: s.substring(n, s.length - n), style: content));
    out.add(TextSpan(text: s.substring(s.length - n), style: marker));
  }
}
