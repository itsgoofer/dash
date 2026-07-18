import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../vault/templates.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';

/// Apply a saved template's fields+body onto the current item, or save the
/// current item as a new template. Backend lives in lib/vault/templates.dart.
class TemplateMenu extends ConsumerStatefulWidget {
  const TemplateMenu({
    super.key,
    required this.fields,
    required this.body,
    required this.onSetField,
    required this.onSetBody,
  });
  final Map<String, dynamic> fields;
  final String body;
  final void Function(String name, dynamic value) onSetField;
  final ValueChanged<String> onSetBody;

  @override
  ConsumerState<TemplateMenu> createState() => _TemplateMenuState();
}

class _TemplateMenuState extends ConsumerState<TemplateMenu> {
  List<TemplateRef>? _templates;
  String? _loadedRoot;

  Future<void> _load(String root) async {
    final list = await listTemplates(root);
    if (!mounted) return;
    setState(() {
      _templates = list;
      _loadedRoot = root;
    });
  }

  Future<void> _apply(TemplateRef template) async {
    final t = await loadTemplate(template.path);
    for (final e in t.fields.entries) {
      widget.onSetField(e.key, e.value);
    }
    if (t.body.isNotEmpty) {
      widget.onSetBody(widget.body.trim().isEmpty ? t.body : '${widget.body}\n\n${t.body}');
    }
  }

  Future<void> _promptSave(BuildContext context, String root) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DashColors.bg1,
        shape: RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder)),
        title: const Text('Save as template', style: DashType.heading),
        content: SizedBox(
          width: 320,
          child: DashTextField(
            controller: controller,
            autofocus: true,
            hint: 'Template name',
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          DashButton('Cancel', onTap: () => Navigator.pop(context)),
          DashButton('Create', kind: DashButtonKind.primary, onTap: () => Navigator.pop(context, controller.text)),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await saveTemplate(root, name.trim(), widget.fields, widget.body);
    if (!mounted) return;
    await _load(root);
  }

  @override
  Widget build(BuildContext context) {
    final root = ref.watch(vaultPathProvider).value;
    if (root == null) return const SizedBox.shrink();
    if (_loadedRoot != root) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(root);
      });
    }
    final templates = _templates ?? const <TemplateRef>[];

    return DashMenuAnchor(
      menuWidth: 220,
      triggerBuilder: (context, open, hovering) => DashIconBtn('book_2', tooltip: 'Templates', onTap: null),
      contentBuilder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: DashSpace.x1),
              child: Text('No templates yet.', style: DashType.small),
            )
          else
            for (final t in templates)
              _MenuRow(
                icon: 'book_2',
                label: t.name,
                onTap: () {
                  close();
                  _apply(t);
                },
              ),
          if (templates.isNotEmpty)
            Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: DashColors.glassBorder),
          _MenuRow(
            icon: 'add',
            label: 'Save as template…',
            onTap: () {
              close();
              _promptSave(context, root);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovering ? DashColors.text0 : DashColors.text1;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DashMotion.hover,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          decoration: BoxDecoration(
            color: _hovering ? DashColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              DashIcon(widget.icon, size: 14, color: color),
              const SizedBox(width: DashSpace.x2),
              Expanded(child: Text(widget.label, style: DashType.body.copyWith(fontSize: 13, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
