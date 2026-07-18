import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import 'blocks/read_view.dart';
import 'markdown_editing_controller.dart';

const _imageExts = {'.png', '.jpg', '.jpeg', '.gif', '.webp'};

/// Reusable note body editor: a full-height markdown TextField styled as a
/// document, on a ~720px reading measure. Stage-B polish: cursor-aware syntax
/// hiding (in the controller), image/file paste + drag into the vault, an
/// Obsidian-like read/edit toggle (⌘E, eye button) rendering [MarkdownReadView],
/// and a `/` slash menu for inserting blocks. Text is only ever changed through
/// ordinary [TextEditingValue] replacement, so undo and fidelity are preserved.
class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.autofocus = false,
    this.centered = true,
  });

  final String initialText;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final bool centered;

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late final MarkdownEditingController _controller = MarkdownEditingController(text: widget.initialText);
  final _fieldKey = GlobalKey();
  bool _readMode = false;
  bool _dragging = false;

  // Slash-menu state.
  OverlayEntry? _slashOverlay;
  int _slashStart = 0;
  String _slashQuery = '';
  int _slashSelected = 0;
  bool get _slashOpen => _slashOverlay != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeSlash);
  }

  @override
  void didUpdateWidget(NoteEditor old) {
    super.didUpdateWidget(old);
    if (widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(text: widget.initialText);
    }
  }

  @override
  void dispose() {
    _closeSlash();
    _controller.dispose();
    super.dispose();
  }

  String get _root => ref.read(vaultPathProvider).value ?? '';

  /// Current read state for use in callbacks (ref.watch is build-only).
  bool get _readNow => ref.read(editorReadModeProvider) ?? _readMode;

  // ── Text insertion (always via ordinary replacement — undo-friendly) ──────

  void _insert(String snippet) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, snippet);
    _controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: start + snippet.length));
    widget.onChanged(newText);
    if (mounted) setState(() {});
  }

  void _replaceRange(int start, int end, String repl, TextSelection sel) {
    final newText = _controller.text.replaceRange(start, end, repl);
    _controller.value = TextEditingValue(text: newText, selection: sel);
    widget.onChanged(newText);
    if (mounted) setState(() {});
  }

  /// ⌘B/I/U toggle: unwraps when the selection contains or is surrounded by
  /// the markers, wraps (and keeps the content selected) otherwise.
  void _toggleWrap(String l, String r) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final start = sel.start, end = sel.end;
    final inner = text.substring(start, end);
    if (inner.length >= l.length + r.length && inner.startsWith(l) && inner.endsWith(r)) {
      final un = inner.substring(l.length, inner.length - r.length);
      return _replaceRange(start, end, un, TextSelection(baseOffset: start, extentOffset: start + un.length));
    }
    if (start >= l.length && text.startsWith(r, end) && text.substring(start - l.length, start) == l) {
      return _replaceRange(start - l.length, end + r.length, inner,
          TextSelection(baseOffset: start - l.length, extentOffset: start - l.length + inner.length));
    }
    _replaceRange(start, end, '$l$inner$r',
        TextSelection(baseOffset: start + l.length, extentOffset: start + l.length + inner.length));
  }

  /// ⌘K: selection → `[selection](‸)`, empty → `[‸]()`, existing link → label.
  void _toggleLink() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final start = sel.start, end = sel.end;
    final inner = text.substring(start, end);
    final m = RegExp(r'^\[([^\]]*)\]\(([^)]*)\)$').firstMatch(inner);
    if (m != null) {
      final label = m.group(1)!;
      return _replaceRange(start, end, label, TextSelection(baseOffset: start, extentOffset: start + label.length));
    }
    inner.isEmpty
        ? _replaceRange(start, end, '[]()', TextSelection.collapsed(offset: start + 1))
        : _replaceRange(start, end, '[$inner]()', TextSelection.collapsed(offset: start + inner.length + 3));
  }

  void _onReadChanged(String body) {
    _controller.value = TextEditingValue(text: body, selection: _controller.selection);
    widget.onChanged(body);
    setState(() {});
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Future<void> _saveAndInsert(List<int> bytes, String originalName, {bool isPaste = false}) async {
    final root = _root;
    if (root.isEmpty) return;
    final rel = await ref.read(vaultFsProvider).saveAttachment(root, bytes, originalName: originalName, isPaste: isPaste);
    final isImg = _imageExts.contains(p.extension(originalName).toLowerCase());
    _insert(isImg ? '![]($rel)' : '[${p.basename(originalName)}]($rel)');
  }

  Future<void> _onDrop(DropDoneDetails d) async {
    setState(() => _dragging = false);
    for (final f in d.files) {
      try {
        await _saveAndInsert(await f.readAsBytes(), f.name);
      } catch (_) {/* skip unreadable item */}
    }
  }

  Future<void> _handlePaste() async {
    try {
      final clip = SystemClipboard.instance;
      if (clip != null) {
        final reader = await clip.read();
        for (final fmt in const [Formats.png, Formats.jpeg, Formats.gif, Formats.webp]) {
          if (reader.canProvide(fmt)) {
            final done = Completer<void>();
            reader.getFile(fmt, (file) async {
              try {
                await _saveAndInsert(await file.readAll(), 'pasted${_extForFormat(fmt)}', isPaste: true);
              } finally {
                if (!done.isCompleted) done.complete();
              }
            }, onError: (_) => done.isCompleted ? null : done.complete());
            await done.future;
            return;
          }
        }
        final text = await reader.readValue(Formats.plainText);
        if (text != null && text.isNotEmpty) return _insert(text);
      }
    } catch (_) {/* fall through to plain-text clipboard */}
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) _insert(data.text!);
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.pickFiles(type: FileType.image, allowMultiple: false);
    final path = (res == null || res.files.isEmpty) ? null : res.files.first.path;
    if (path == null) return;
    await _saveAndInsert(await File(path).readAsBytes(), p.basename(path));
  }

  String _extForFormat(FileFormat f) =>
      f == Formats.jpeg ? '.jpg' : f == Formats.gif ? '.gif' : f == Formats.webp ? '.webp' : '.png';

  // ── Read/edit toggle ──────────────────────────────────────────────────────

  void _toggleRead() {
    ref.read(editorReadModeProvider.notifier).set(null); // release any global override
    setState(() => _readMode = !_readNow);
    _closeSlash();
  }

  // ── Slash menu ──────────────────────────────────────────────────────────────

  static const _items = [
    (label: 'Heading 1', icon: 'title', snippet: '# ', image: false),
    (label: 'Heading 2', icon: 'title', snippet: '## ', image: false),
    (label: 'Heading 3', icon: 'title', snippet: '### ', image: false),
    (label: 'Task', icon: 'checklist', snippet: '- [ ] ', image: false),
    (label: 'Bullet list', icon: 'format_list_bulleted', snippet: '- ', image: false),
    (label: 'Divider', icon: 'horizontal_rule', snippet: '---\n', image: false),
    (label: 'Image', icon: 'image', snippet: '', image: true),
  ];

  List<({String label, String icon, String snippet, bool image})> get _filtered =>
      _items.where((i) => i.label.toLowerCase().replaceAll(' ', '').contains(_slashQuery)).toList();

  void _maybeSlash() {
    if (_readNow) return _closeSlash();
    final sel = _controller.selection;
    if (!sel.isCollapsed || sel.baseOffset < 0) return _closeSlash();
    final caret = sel.baseOffset;
    final text = _controller.text;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    final m = RegExp(r'^/(\w*)$').firstMatch(text.substring(lineStart, caret));
    if (m == null) return _closeSlash();
    _slashStart = lineStart;
    _slashQuery = m.group(1)!.toLowerCase();
    if (_filtered.isEmpty) return _closeSlash();
    _slashSelected = _slashSelected.clamp(0, _filtered.length - 1);
    if (_slashOverlay == null) {
      _slashOverlay = OverlayEntry(builder: _buildSlashMenu);
      Overlay.of(context).insert(_slashOverlay!);
    } else {
      _slashOverlay!.markNeedsBuild();
    }
  }

  void _closeSlash() {
    _slashOverlay?.remove();
    _slashOverlay = null;
    _slashSelected = 0;
  }

  void _moveSlash(int delta) {
    final n = _filtered.length;
    if (n == 0) return;
    _slashSelected = (_slashSelected + delta + n) % n;
    _slashOverlay?.markNeedsBuild();
  }

  void _selectSlash() {
    if (_filtered.isEmpty) return;
    final item = _filtered[_slashSelected.clamp(0, _filtered.length - 1)];
    final caret = _controller.selection.baseOffset;
    _controller.selection = TextSelection(baseOffset: _slashStart, extentOffset: caret);
    _closeSlash();
    if (item.image) {
      _insert('');
      _pickImage();
    } else {
      _insert(item.snippet);
    }
  }

  Offset _caretGlobal() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final tp = TextPainter(
      text: _controller.buildTextSpan(context: context, style: DashType.body, withComposing: false),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: box.size.width);
    final o = tp.getOffsetForCaret(
      TextPosition(offset: _slashStart.clamp(0, _controller.text.length)),
      Rect.zero,
    );
    return box.localToGlobal(Offset(o.dx, o.dy + tp.preferredLineHeight + DashSpace.x1));
  }

  Widget _buildSlashMenu(BuildContext context) {
    final pos = _caretGlobal();
    final screen = MediaQuery.of(context).size;
    final items = _filtered;
    const w = 240.0;
    final h = items.length * 32.0 + DashSpace.x1 * 2;
    final left = pos.dx.clamp(0, screen.width - w - DashSpace.x2).toDouble();
    final top = (pos.dy + h > screen.height ? pos.dy - h - DashSpace.x4 : pos.dy).clamp(0, screen.height - h).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: TapRegion(
        onTapOutside: (_) => _closeSlash(),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: w,
            padding: const EdgeInsets.symmetric(vertical: DashSpace.x1),
            decoration: BoxDecoration(
              color: DashColors.bg1,
              borderRadius: DashRadius.br,
              border: Border.all(color: DashColors.glassBorder),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 32)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _SlashRow(
                    label: items[i].label,
                    icon: items[i].icon,
                    selected: i == _slashSelected,
                    onTap: () {
                      _slashSelected = i;
                      _selectSlash();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;
    if (meta && k == LogicalKeyboardKey.keyE) {
      _toggleRead();
      return KeyEventResult.handled;
    }
    if (_slashOpen) {
      if (k == LogicalKeyboardKey.arrowDown) {
        _moveSlash(1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        _moveSlash(-1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.tab) {
        _selectSlash();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        _closeSlash();
        return KeyEventResult.handled;
      }
    }
    if (e is KeyDownEvent && meta && !_readNow) {
      if (k == LogicalKeyboardKey.keyB) {
        _toggleWrap('**', '**');
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyI) {
        _toggleWrap('*', '*');
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyU) {
        _toggleWrap('<u>', '</u>');
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyK) {
        _toggleLink();
        return KeyEventResult.handled;
      }
    }
    if (meta && k == LogicalKeyboardKey.keyV && !_readNow) {
      _handlePaste();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final read = ref.watch(editorReadModeProvider) ?? _readMode;
    final Widget surface = read
        ? MarkdownReadView(body: _controller.text, vaultRoot: _root, onChanged: _onReadChanged, centered: widget.centered)
        : _editField();

    return Stack(
      children: [
        Positioned.fill(child: surface),
        Positioned(top: 0, right: 0, child: _ToggleButton(read: read, onTap: _toggleRead)),
      ],
    );
  }

  Widget _editField() {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: DropTarget(
        onDragDone: _onDrop,
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        child: Container(
          decoration: _dragging
              ? BoxDecoration(borderRadius: DashRadius.br, border: Border.all(color: DashColors.accent), color: DashColors.accentDim)
              : null,
          child: Align(
            alignment: widget.centered ? Alignment.topCenter : Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: TextField(
                key: _fieldKey,
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
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  const _ToggleButton({required this.read, required this.onTap});
  final bool read;
  final VoidCallback onTap;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.read ? 'Edit (⌘E)' : 'Read (⌘E)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: DashSize.iconButton,
            height: DashSize.iconButton,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? DashColors.hover : DashColors.bg1.withValues(alpha: 0.6),
              borderRadius: DashRadius.br,
              border: Border.all(color: DashColors.glassBorder),
            ),
            child: DashIcon(
              widget.read ? 'edit' : 'visibility',
              size: 16,
              color: widget.read ? DashColors.accent : DashColors.text1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashRow extends StatefulWidget {
  const _SlashRow({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SlashRow> createState() => _SlashRowState();
}

class _SlashRowState extends State<_SlashRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          color: active ? DashColors.active : Colors.transparent,
          child: Row(
            children: [
              DashIcon(widget.icon, size: 16, color: active ? DashColors.accent : DashColors.text1),
              const SizedBox(width: DashSpace.x2),
              Text(widget.label, style: DashType.label.copyWith(color: active ? DashColors.text0 : DashColors.text1)),
            ],
          ),
        ),
      ),
    );
  }
}
