import 'package:flutter/material.dart';

import '../../theme/dash_theme.dart';

/// Stage A source-first editor: a [TextEditingController] that styles the
/// markdown source *as a document* without ever altering the text — headings
/// at display sizes, real bold/italic, dimmed syntax markers, styled tasks and
/// links. The parser is line-based with simple inline regexes, recomputed per
/// [buildTextSpan] (documents are personal-scale).
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  static final _heading = RegExp(r'^(#{1,3}) ');
  static final _task = RegExp(r'^(\s*- \[[ xX]\] )');
  static final _quote = RegExp(r'^(>+ ?)');
  static final _link = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
  static final _inline = RegExp(
    r'(`[^`]+`)' // 1 code
    r'|(\[[^\]]*\]\([^)]*\))' // 2 link
    r'|(\*\*[^*]+\*\*)' // 3 bold
    r'|(~~[^~]+~~)' // 4 strike
    r'|(\*[^*\n]+\*)', // 5 italic
  );

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? DashType.body;
    final marker = base.copyWith(color: DashColors.text2, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal);
    final codeBlock = base.copyWith(fontFamily: DashType.codeFamily, fontSize: 13, color: DashColors.text1, height: 1.5);

    final children = <InlineSpan>[];
    final lines = text.split('\n');
    var inFence = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isFence = line.trimLeft().startsWith('```');

      if (isFence || inFence) {
        children.add(TextSpan(text: line, style: codeBlock));
        if (isFence) inFence = !inFence;
      } else {
        _styleLine(line, base, marker, children);
      }
      if (i != lines.length - 1) children.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(style: base, children: children);
  }

  void _styleLine(String line, TextStyle base, TextStyle marker, List<InlineSpan> out) {
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final hStyle = switch (level) { 1 => DashType.editorH1, 2 => DashType.editorH2, _ => DashType.editorH3 };
      out.add(TextSpan(text: line.substring(0, heading.end), style: marker.merge(hStyle).copyWith(color: DashColors.text2)));
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
      _inlineSpans(line.substring(task.end), body, marker, out);
      return;
    }

    final quote = _quote.firstMatch(line);
    if (quote != null) {
      out.add(TextSpan(text: line.substring(0, quote.end), style: marker));
      _inlineSpans(line.substring(quote.end), base.copyWith(color: DashColors.text0, fontStyle: FontStyle.italic), marker, out);
      return;
    }

    _inlineSpans(line, base, marker, out);
  }

  /// Emits inline-styled spans for [text], reconstructing every character
  /// exactly (markers dimmed, content styled).
  void _inlineSpans(String text, TextStyle base, TextStyle marker, List<InlineSpan> out) {
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
        final l = _link.firstMatch(s)!;
        out.add(TextSpan(text: '[', style: marker));
        out.add(TextSpan(text: l.group(1), style: base.copyWith(color: DashColors.accent)));
        out.add(TextSpan(text: '](${l.group(2)})', style: marker));
      } else if (m.group(3) != null) {
        _wrap(s, 2, base.copyWith(fontWeight: FontWeight.w700, color: DashColors.text0), marker, out);
      } else if (m.group(4) != null) {
        _wrap(s, 2, base.copyWith(decoration: TextDecoration.lineThrough, color: DashColors.text1), marker, out);
      } else {
        _wrap(s, 1, base.copyWith(fontStyle: FontStyle.italic), marker, out);
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last), style: base));
  }

  /// Dimmed marker of width [n] on each side, styled content between.
  void _wrap(String s, int n, TextStyle content, TextStyle marker, List<InlineSpan> out) {
    out.add(TextSpan(text: s.substring(0, n), style: marker));
    out.add(TextSpan(text: s.substring(n, s.length - n), style: content));
    out.add(TextSpan(text: s.substring(s.length - n), style: marker));
  }
}
