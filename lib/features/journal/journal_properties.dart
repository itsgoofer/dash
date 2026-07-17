import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';

const _props = [
  (key: 'energy', label: 'Energy', icon: 'bolt'),
  (key: 'rating', label: 'Day rating', icon: 'star'),
  (key: 'productivity', label: 'Productivity', icon: 'check'),
  (key: 'exercise', label: 'Exercise', icon: 'exercise'),
  (key: 'gaming', label: 'Gaming', icon: 'stadia_controller'),
];

/// Notion-style property rows for the journal metrics: quiet label/value
/// pairs; clicking a value opens a compact 1-10 picker. No sliders.
class JournalProperties extends ConsumerWidget {
  const JournalProperties({super.key, required this.date, required this.metrics});

  final DateTime date;
  final Map<String, int> metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(journalNoteProvider(date).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in _props)
          _PropertyRow(
            label: p.label,
            icon: p.icon,
            value: metrics[p.key],
            onChanged: (v) => notifier.setMetric(p.key, v),
          ),
      ],
    );
  }
}

class _PropertyRow extends StatefulWidget {
  const _PropertyRow({required this.label, required this.icon, required this.value, required this.onChanged});

  final String label;
  final String icon;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  State<_PropertyRow> createState() => _PropertyRowState();
}

class _PropertyRowState extends State<_PropertyRow> {
  final _menu = MenuController();
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: MenuAnchor(
        controller: _menu,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(DashColors.bg1),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder))),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(DashSpace.x1)),
        ),
        menuChildren: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 10; i++) _PickCell(value: i, current: widget.value, onTap: () {
                widget.onChanged(i);
                _menu.close();
              }),
            ],
          ),
        ],
        child: GestureDetector(
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: DashSpace.x1),
            decoration: BoxDecoration(
              color: _hovering ? DashColors.hover : Colors.transparent,
              borderRadius: DashRadius.br,
            ),
            child: Row(
              children: [
                DashIcon(widget.icon, size: 13, color: DashColors.text2),
                const SizedBox(width: DashSpace.x2),
                SizedBox(width: 96, child: Text(widget.label, style: DashType.label.copyWith(color: DashColors.text1))),
                const SizedBox(width: DashSpace.x3),
                widget.value == null
                    ? Text('Empty', style: DashType.small.copyWith(color: DashColors.text2))
                    : Row(children: [
                        Text('${widget.value}', style: DashType.mono.copyWith(color: DashColors.text0)),
                        Text(' / 10', style: DashType.small.copyWith(color: DashColors.text2)),
                      ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickCell extends StatefulWidget {
  const _PickCell({required this.value, required this.current, required this.onTap});
  final int value;
  final int? current;
  final VoidCallback onTap;

  @override
  State<_PickCell> createState() => _PickCellState();
}

class _PickCellState extends State<_PickCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.current != null && widget.value <= widget.current!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 24,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering
                ? DashColors.accentDim
                : active
                    ? DashColors.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: DashRadius.br,
          ),
          child: Text('${widget.value}',
              style: DashType.small.copyWith(
                  color: _hovering || widget.value == widget.current ? DashColors.accent : active ? DashColors.text0 : DashColors.text1)),
        ),
      ),
    );
  }
}
