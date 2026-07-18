import 'package:flutter/material.dart';

import '../../theme/dash_theme.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_icon.dart';

/// Semantic color for a project status value (falls back to [DashChip]'s
/// hashed palette for anything unrecognized).
Color statusColor(String status) => switch (status) {
      'active' || 'in progress' => DashColors.accent,
      'done' => DashColors.success,
      'paused' => DashColors.warning,
      'cancelled' => DashColors.danger,
      _ => DashChip.optionColor(status), // planning, pending, and any custom value
    };

/// Thin 2px task-progress bar: `glassBorder` track, accent fill.
class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({super.key, required this.value});
  final double value; // 0..1

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: SizedBox(
          height: 2,
          child: Stack(
            children: [
              Container(color: DashColors.glassBorder),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0, 1),
                child: Container(color: DashColors.accent),
              ),
            ],
          ),
        ),
      );
}

/// Free-form multiselect tag editor: chips with a remove (x), plus an inline
/// add field — used for a project's `software` tags (schema has no fixed
/// option list for it).
class SoftwareChipsEditor extends StatefulWidget {
  const SoftwareChipsEditor({super.key, required this.value, required this.onChanged});
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SoftwareChipsEditor> createState() => _SoftwareChipsEditorState();
}

class _SoftwareChipsEditorState extends State<SoftwareChipsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final t = raw.trim();
    _controller.clear();
    if (t.isEmpty || widget.value.contains(t)) return;
    widget.onChanged([...widget.value, t]);
  }

  void _remove(String tag) => widget.onChanged(widget.value.where((s) => s != tag).toList());

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DashSpace.x1,
      runSpacing: DashSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in widget.value)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _remove(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 3),
                decoration: BoxDecoration(
                  color: DashChip.optionColor(tag).withValues(alpha: 0.15),
                  borderRadius: DashRadius.br,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tag,
                        style: DashType.small
                            .copyWith(color: DashChip.optionColor(tag), fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    DashIcon('close', size: 12, color: DashChip.optionColor(tag)),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          width: 110,
          height: DashSize.controlCompact,
          child: TextField(
            controller: _controller,
            style: DashType.small,
            decoration: const InputDecoration(isDense: true, hintText: '+ software'),
            onSubmitted: _add,
          ),
        ),
      ],
    );
  }
}
