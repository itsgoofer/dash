import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:macos_window_utils/widgets/titlebar_safe_area.dart';
import 'package:path/path.dart' as p;

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/glow_text.dart';
import '../dashboard/dashboard_screen.dart';
import '../databases/databases_screen.dart';
import '../journal/journal_screen.dart';
import '../projects/projects_screen.dart';
import 'boot_screen.dart';
import 'command_palette.dart';
import 'vault_picker.dart';

/// Top-level gate: shows the vault picker until a vault path is chosen, then
/// the shell with the boot-sequence overlay above it (once per launch).
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultPath = ref.watch(vaultPathProvider);
    final booted = ref.watch(bootCompleteProvider);
    return switch (vaultPath) {
      AsyncData(:final value) when value != null => Stack(
        fit: StackFit.expand,
        children: [const Shell(), if (!booted) const BootScreen()],
      ),
      AsyncLoading() => Scaffold(
        backgroundColor: DashColors.bg0,
        body: Center(
          child: CircularProgressIndicator(color: DashColors.accent),
        ),
      ),
      _ => const VaultPicker(),
    };
  }
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  static const _sections = [
    (section: ShellSection.dashboard, icon: 'dashboard', label: 'DASHBOARD'),
    (section: ShellSection.journal, icon: 'book_2', label: 'JOURNAL'),
    (section: ShellSection.databases, icon: 'database', label: 'DATABASES'),
    (section: ShellSection.projects, icon: 'deployed_code', label: 'PROJECTS'),
  ];

  /// Section switch: fade + 8px vertical drift + 0.985→1 scale.
  static Widget _transition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - curved.value)),
          child: Transform.scale(
            scale: 0.985 + 0.015 * curved.value,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(shellSectionProvider);

    return Scaffold(
      backgroundColor: DashColors.bg0,
      body: TitlebarSafeArea(
        child: CommandPaletteScope(
          child: Column(
            children: [
              const _HudBar(),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const AmbientBackdrop(),
                    Padding(
                      padding: const EdgeInsets.all(DashSpace.x4),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: _transition,
                        child: KeyedSubtree(
                          key: ValueKey(selected),
                          child: switch (selected) {
                            ShellSection.dashboard => const DashboardScreen(),
                            ShellSection.journal => const JournalScreen(),
                            ShellSection.databases => const DatabasesScreen(),
                            ShellSection.projects => const ProjectsScreen(),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ~46px frameless HUD strip: wordmark + status dot, section tabs with a
/// sliding accent underline, then clock / vault chip / accent picker.
class _HudBar extends StatelessWidget {
  const _HudBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          color: DashColors.bg1.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3),
          child: Row(
            children: [
              const GlowText('DASH', style: DashType.title),
              const SizedBox(width: DashSpace.x2),
              const _StatusDot(),
              const SizedBox(width: DashSpace.x5),
              const Expanded(child: _HudTabs()),
              const SizedBox(width: DashSpace.x3),
              const _HudClock(),
              const SizedBox(width: DashSpace.x3),
              const _VaultChip(),
              const SizedBox(width: DashSpace.x2),
              const _AccentPicker(),
            ],
          ),
        ),
        // Hairline bottom border with a subtle accent gradient.
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                DashColors.accent.withValues(alpha: 0.45),
                DashColors.accent.withValues(alpha: 0.10),
                DashColors.glassBorder,
              ],
              stops: const [0, 0.25, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pulsing accent square next to the wordmark — the "system alive" glyph.
class _StatusDot extends StatefulWidget {
  const _StatusDot();

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: DashColors.accent,
          borderRadius: BorderRadius.circular(1),
          boxShadow: [
            BoxShadow(
              color: DashColors.accent.withValues(alpha: 0.7),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section tabs with a 2px glowing underline that slides between tabs.
class _HudTabs extends ConsumerStatefulWidget {
  const _HudTabs();

  @override
  ConsumerState<_HudTabs> createState() => _HudTabsState();
}

class _HudTabsState extends ConsumerState<_HudTabs> {
  final _rowKey = GlobalKey();
  final _tabKeys = {for (final s in Shell._sections) s.section: GlobalKey()};
  Rect? _indicator;

  void _measure(ShellSection selected) {
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final tab =
        _tabKeys[selected]?.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || tab == null || !row.attached || !tab.attached) return;
    final origin = tab.localToGlobal(Offset.zero, ancestor: row);
    final rect = Rect.fromLTWH(origin.dx, 0, tab.size.width, 2);
    if (rect != _indicator && mounted) setState(() => _indicator = rect);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(shellSectionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(selected));

    // scaleDown: at narrow window widths the tab strip shrinks a touch
    // instead of overflowing the HUD bar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            key: _rowKey,
            children: [
              for (final item in Shell._sections)
                _HudTab(
                  key: _tabKeys[item.section],
                  icon: item.icon,
                  label: item.label,
                  selected: selected == item.section,
                  onTap: () => ref
                      .read(shellSectionProvider.notifier)
                      .select(item.section),
                ),
            ],
          ),
          if (_indicator != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: _indicator!.left,
              width: _indicator!.width,
              bottom: 0,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: DashColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: DashColors.accent.withValues(alpha: 0.65),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HudTab extends StatefulWidget {
  const _HudTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_HudTab> createState() => _HudTabState();
}

class _HudTabState extends State<_HudTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? DashColors.accent
        : _hovering
        ? DashColors.text0
        : DashColors.text1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DashIcon(widget.icon, size: 14, color: color),
                const SizedBox(width: DashSpace.x1 + 2),
                AnimatedDefaultTextStyle(
                  duration: DashMotion.hover,
                  curve: DashMotion.curve,
                  style: DashType.hudLabel.copyWith(color: color),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live HH:MM:SS clock — its own 1s timer so nothing else rebuilds with it.
class _HudClock extends StatefulWidget {
  const _HudClock();

  @override
  State<_HudClock> createState() => _HudClockState();
}

class _HudClockState extends State<_HudClock> {
  static final _fmt = DateFormat('HH:mm:ss');
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _fmt.format(_now),
    style: DashType.clockSmall.copyWith(color: DashColors.text1),
  );
}

/// Condensed vault chip: vault name plus the conflicted-copy warning that
/// lived in the old sidebar banner (icon + count, full message in a tooltip).
class _VaultChip extends ConsumerWidget {
  const _VaultChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultPath = ref.watch(vaultPathProvider).value;
    final index = ref.watch(indexProvider).value;
    if (vaultPath == null) return const SizedBox.shrink();

    final conflicts = index?.conflictedPaths.length ?? 0;
    final chip = Container(
      height: DashSize.controlCompact,
      padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
      decoration: BoxDecoration(
        color: DashColors.glassFill,
        borderRadius: DashRadius.br,
        border: Border.all(
          color: conflicts > 0
              ? DashColors.warning.withValues(alpha: 0.5)
              : DashColors.glassBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conflicts > 0) ...[
            const DashIcon('warning', size: 12, color: DashColors.warning),
            const SizedBox(width: DashSpace.x1),
            Text(
              '$conflicts',
              style: DashType.small.copyWith(color: DashColors.warning),
            ),
            const SizedBox(width: DashSpace.x2),
          ],
          Text(
            p.basename(vaultPath).toUpperCase(),
            style: DashType.hudLabel.copyWith(
              fontSize: 10.5,
              letterSpacing: 1.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return conflicts > 0
        ? Tooltip(
            message:
                '$conflicts conflicted ${conflicts == 1 ? 'copy' : 'copies'} in the vault',
            child: chip,
          )
        : chip;
  }
}

/// Settings gear → accent color swatches (persisted per-vault).
class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(accentProvider).value ?? 'cyan';
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(DashColors.bg1),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: DashRadius.br,
            side: BorderSide(color: DashColors.glassBorder),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(DashSpace.x2)),
      ),
      menuChildren: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in DashColors.accents.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: e.key,
                  child: GestureDetector(
                    onTap: () => ref.read(accentProvider.notifier).set(e.key),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: e.value,
                          borderRadius: DashRadius.br,
                          border: e.key == current
                              ? Border.all(color: DashColors.text0, width: 1.5)
                              : null,
                          boxShadow: e.key == current
                              ? [
                                  BoxShadow(
                                    color: e.value.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      builder: (context, controller, _) => GestureDetector(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DashIcon('settings', size: 14, color: DashColors.text2),
        ),
      ),
    );
  }
}
