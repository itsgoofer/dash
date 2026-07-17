import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';

/// Compact month calendar — the journal's primary navigation. Dots mark days
/// with entries; click a day to open it. Future days are disabled.
class JournalCalendar extends ConsumerStatefulWidget {
  const JournalCalendar({super.key});

  @override
  ConsumerState<JournalCalendar> createState() => _JournalCalendarState();
}

class _JournalCalendarState extends ConsumerState<JournalCalendar> {
  late DateTime _month; // first day of displayed month

  @override
  void initState() {
    super.initState();
    final s = ref.read(selectedJournalDateProvider);
    _month = DateTime(s.year, s.month);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedJournalDateProvider);
    final logged = ref.watch(indexProvider).value?.journalByDate.keys.toSet() ?? const <DateTime>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstWeekday = _month.weekday; // 1 = Mon
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 1; i < firstWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(_month.year, _month.month, d),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(DateFormat('MMMM yyyy').format(_month),
                style: DashType.label.copyWith(color: DashColors.text0)),
            const Spacer(),
            _MonthButton(icon: 'chevron_left', onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
            _MonthButton(
              icon: 'chevron_right',
              onTap: _month.isBefore(DateTime(today.year, today.month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x2),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final wd in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Center(child: Text(wd, style: DashType.small.copyWith(color: DashColors.text2, fontSize: 10))),
            for (final day in cells)
              day == null
                  ? const SizedBox.shrink()
                  : _DayCell(
                      day: day,
                      selected: day == selected,
                      today: day == today,
                      logged: logged.contains(day),
                      enabled: !day.isAfter(today),
                      onTap: () => ref.read(selectedJournalDateProvider.notifier).set(day),
                    ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.logged,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected, today, logged, enabled;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = !widget.enabled
        ? DashColors.text2
        : widget.selected
            ? DashColors.accent
            : DashColors.text1;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: DashMotion.hover,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: widget.selected
                ? DashColors.accentDim
                : _hovering && widget.enabled
                    ? DashColors.hover
                    : Colors.transparent,
            borderRadius: DashRadius.br,
            border: widget.today ? Border.all(color: DashColors.accent.withValues(alpha: 0.5)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${widget.day.day}',
                  style: DashType.small.copyWith(color: color, fontSize: 10.5, height: 1)),
              const SizedBox(height: 2),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.logged ? DashColors.accent : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.only(left: DashSpace.x1),
          child: DashIcon(icon, size: 14, color: onTap != null ? DashColors.text1 : DashColors.text2),
        ),
      ),
    );
  }
}
