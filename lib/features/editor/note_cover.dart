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
class NoteCoverHeader extends ConsumerStatefulWidget {
  const NoteCoverHeader({super.key, required this.cover, required this.onChanged, required this.title});

  final String? cover;
  final ValueChanged<String?> onChanged;
  final Widget title;

  @override
  ConsumerState<NoteCoverHeader> createState() => _NoteCoverHeaderState();
}

class _NoteCoverHeaderState extends ConsumerState<NoteCoverHeader> {
  bool _hoverBanner = false;
  bool _hoverTitle = false;

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

  Widget _banner(String root) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverBanner = true),
      onExit: (_) => setState(() => _hoverBanner = false),
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: DashSpace.x3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: DashRadius.br),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(p.join(root, widget.cover!)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: DashColors.bg1,
                alignment: Alignment.center,
                child: Text('Missing cover: ${widget.cover}', style: DashType.small.copyWith(color: DashColors.text2)),
              ),
            ),
            // Bottom gradient into bg0 so the title area below stays legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0008090D), Color(0x9908090D)],
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
