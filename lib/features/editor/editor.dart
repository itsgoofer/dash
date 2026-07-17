import 'package:flutter/material.dart';

import '../../theme/dash_theme.dart';
import 'markdown_editing_controller.dart';

/// Reusable note body editor: a full-height markdown TextField styled as a
/// document, on a ~720px reading measure, borderless (sits on bg0).
class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.initialText, required this.onChanged, this.autofocus = false});

  final String initialText;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final MarkdownEditingController _controller = MarkdownEditingController(text: widget.initialText);

  @override
  void didUpdateWidget(NoteEditor old) {
    super.didUpdateWidget(old);
    // External reload: adopt the new text unless it already matches (avoids
    // clobbering the caret while the user types).
    if (widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(text: widget.initialText);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          autofocus: widget.autofocus,
          expands: true,
          maxLines: null,
          minLines: null,
          cursorColor: DashColors.accent,
          style: DashType.body,
          scrollPadding: const EdgeInsets.symmetric(vertical: DashSpace.x6),
          decoration: const InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: "Nothing logged yet — today's a blank page.",
          ),
        ),
      ),
    );
  }
}
