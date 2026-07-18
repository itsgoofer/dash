import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';

/// Notion-style cover header: full-width banner above [title] when a
/// frontmatter `cover:` path is set (hover → change/remove), and a subtle
/// hover-revealed "Add cover" affordance when it isn't. Picked images are
/// copied into the vault's Attachments/ so the vault stays self-contained;
/// [onChanged] receives the vault-relative path (or null on remove).
const _kCoverH = 200.0;

class NoteCoverHeader extends ConsumerStatefulWidget {
  const NoteCoverHeader({
    super.key,
    required this.cover,
    required this.onChanged,
    required this.title,
    this.coverY = 0.5,
    this.onReposition,
  });

  final String? cover;
  final ValueChanged<String?> onChanged;
  final Widget title;

  /// Vertical focal point of the cover image, 0 (top) → 1 (bottom). Drag the
  /// banner to change it; persisted by the owner via [onReposition].
  final double coverY;
  final ValueChanged<double>? onReposition;

  @override
  ConsumerState<NoteCoverHeader> createState() => _NoteCoverHeaderState();
}

class _NoteCoverHeaderState extends ConsumerState<NoteCoverHeader> {
  bool _hoverBanner = false;
  bool _hoverTitle = false;
  double? _dragY; // live focal point while dragging (overrides widget.coverY)

  double get _y => (_dragY ?? widget.coverY).clamp(0.0, 1.0);

  @override
  void didUpdateWidget(NoteCoverHeader old) {
    super.didUpdateWidget(old);
    if (old.cover != widget.cover) _dragY = null; // new image → reset focus
  }

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.image, allowMultiple: false);
    final f = (res == null || res.files.isEmpty) ? null : res.files.first;
    final bytes = f == null ? null : f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (f == null || bytes == null) return;
    final root = ref.read(vaultPathProvider).value;
    if (root == null || root.isEmpty) return;
    final rel = await ref.read(vaultFsProvider).saveAttachment(root, bytes, originalName: f.name);
    widget.onChanged(rel);
  }

  @override
  Widget build(BuildContext context) {
    final root = ref.watch(vaultPathProvider).value ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.cover != null) _banner(root),
        MouseRegion(
          onEnter: (_) => setState(() => _hoverTitle = true),
          onExit: (_) => setState(() => _hoverTitle = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.cover == null)
                SizedBox(
                  height: 22,
                  child: AnimatedOpacity(
                    opacity: _hoverTitle ? 1 : 0,
                    duration: DashMotion.hover,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CoverAction(icon: 'image', label: 'Add cover', onTap: _pick),
                    ),
                  ),
                ),
              widget.title,
            ],
          ),
        ),
      ],
    );
  }

  void _drag(DragUpdateDetails d) {
    if (widget.onReposition == null) return;
    setState(() => _dragY = (_y - d.delta.dy / _kCoverH).clamp(0.0, 1.0));
  }

  Widget _banner(String root) {
    final repositionable = widget.onReposition != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverBanner = true),
      onExit: (_) => setState(() => _hoverBanner = false),
      cursor: repositionable ? SystemMouseCursors.resizeUpDown : MouseCursor.defer,
      child: GestureDetector(
        onVerticalDragUpdate: repositionable ? _drag : null,
        onVerticalDragEnd: repositionable ? (_) => widget.onReposition!(_y) : null,
        child: Container(
          height: _kCoverH,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: DashRadius.br),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(p.join(root, widget.cover!)),
                fit: BoxFit.cover,
                alignment: Alignment(0, _y * 2 - 1),
                errorBuilder: (_, _, _) => Container(
                  color: DashColors.bg1,
                  alignment: Alignment.center,
                  child: Text('Missing cover: ${widget.cover}', style: DashType.small.copyWith(color: DashColors.text2)),
                ),
              ),
            // Fades fully into the page background over the lower third, so the
            // body appears to start right where the fade ends.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, DashColors.bg0],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: DashSpace.x2,
              right: DashSpace.x2,
              child: AnimatedOpacity(
                opacity: _hoverBanner ? 1 : 0,
                duration: DashMotion.hover,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CoverAction(icon: 'image', label: 'Change cover', onTap: _pick),
                    const SizedBox(width: DashSpace.x1),
                    _CoverAction(icon: 'delete', label: 'Remove cover', onTap: () => widget.onChanged(null)),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverAction extends StatefulWidget {
  const _CoverAction({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CoverAction> createState() => _CoverActionState();
}

class _CoverActionState extends State<_CoverAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? DashColors.text0 : DashColors.text1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          decoration: BoxDecoration(
            color: _hover ? DashColors.active : DashColors.bg1.withValues(alpha: 0.75),
            borderRadius: DashRadius.br,
            border: Border.all(color: DashColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DashIcon(widget.icon, size: 13, color: color),
              const SizedBox(width: DashSpace.x1),
              Text(widget.label, style: DashType.small.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
