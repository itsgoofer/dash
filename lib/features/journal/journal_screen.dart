import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../editor/editor.dart';
import '../editor/note_cover.dart';
import 'journal_calendar.dart';
import 'journal_properties.dart';

final _titleFmt = DateFormat('EEEE, MMMM d');

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedJournalDateProvider);
    final isToday = date == _today0();
    final doc = ref.watch(journalNoteProvider(date));

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteCoverHeader(
          cover: doc.value?.cover,
          onChanged: ref.read(journalNoteProvider(date).notifier).setCover,
          title: Row(
            children: [
              Text(_titleFmt.format(date), style: DashType.display),
              if (!isToday) ...[
                const SizedBox(width: DashSpace.x3),
                _NavButton(
                  icon: 'calendar_today',
                  tooltip: 'Today',
                  onTap: ref.read(selectedJournalDateProvider.notifier).goToday,
                ),
              ],
            ],
          ),
        ),
        if (doc.value?.changedOnDisk ?? false)
          _ChangedBanner(onReload: () => ref.read(journalNoteProvider(date).notifier).reload()),
        const SizedBox(height: DashSpace.x3),
        switch (doc) {
          AsyncData(:final value) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 300, child: JournalProperties(date: date, metrics: value.metrics)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DashSpace.x3),
                    child: Container(height: 1, color: DashColors.glassBorder),
                  ),
                  Expanded(
                    child: NoteEditor(
                      key: ValueKey(date),
                      initialText: value.body,
                      onChanged: ref.read(journalNoteProvider(date).notifier).setBody,
                      centered: false,
                    ),
                  ),
                ],
              ),
            ),
          AsyncError(:final error) => Expanded(
              child: Center(child: Text('$error', style: DashType.body.copyWith(color: DashColors.danger))),
            ),
          _ => Expanded(child: Center(child: CircularProgressIndicator(color: DashColors.accent))),
        },
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: main),
        const SizedBox(width: DashSpace.x4),
        const SizedBox(width: 224, child: JournalCalendar()),
      ],
    );
  }
}

DateTime _today0() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class _ChangedBanner extends StatelessWidget {
  const _ChangedBanner({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DashSpace.x3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3, vertical: DashSpace.x2),
        decoration: BoxDecoration(
          color: DashColors.warning.withValues(alpha: 0.12),
          borderRadius: DashRadius.br,
          border: Border.all(color: DashColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const DashIcon('warning', size: 16, color: DashColors.warning),
            const SizedBox(width: DashSpace.x2),
            Expanded(
              child: Text('This day changed on disk while you were editing.',
                  style: DashType.label.copyWith(color: DashColors.warning)),
            ),
            TextButton(onPressed: onReload, child: const Text('Reload')),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({required this.icon, required this.tooltip, required this.onTap});
  final String icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? DashColors.text2
        : _hovering
            ? DashColors.text0
            : DashColors.text1;
    return Padding(
      padding: const EdgeInsets.only(left: DashSpace.x1),
      child: Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: DashSize.iconButton,
              height: DashSize.iconButton,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovering && enabled ? DashColors.hover : Colors.transparent,
                borderRadius: DashRadius.br,
              ),
              child: DashIcon(widget.icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
