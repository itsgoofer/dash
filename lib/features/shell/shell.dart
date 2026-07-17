import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/widgets/titlebar_safe_area.dart';
import 'package:path/path.dart' as p;

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/glow_text.dart';
import '../dashboard/dashboard_screen.dart';
import '../databases/databases_screen.dart';
import '../journal/journal_screen.dart';
import '../projects/projects_screen.dart';
import 'vault_picker.dart';

/// Top-level gate: shows the vault picker until a vault path is chosen, then
/// the normal shell.
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultPath = ref.watch(vaultPathProvider);
    return switch (vaultPath) {
      AsyncData(:final value) when value != null => const Shell(),
      AsyncLoading() => const Scaffold(
        backgroundColor: DashColors.bg0,
        body: Center(child: CircularProgressIndicator(color: DashColors.accent)),
      ),
      _ => const VaultPicker(),
    };
  }
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  static const _sections = [
    (section: ShellSection.dashboard, icon: 'dashboard', label: 'Dashboard'),
    (section: ShellSection.journal, icon: 'book_2', label: 'Journal'),
    (section: ShellSection.databases, icon: 'database', label: 'Databases'),
    (section: ShellSection.projects, icon: 'deployed_code', label: 'Projects'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(shellSectionProvider);

    return Scaffold(
      backgroundColor: DashColors.bg0,
      body: TitlebarSafeArea(
        child: Row(
          children: [
            _Sidebar(selected: selected),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DashSpace.x4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected});

  final ShellSection selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: DashColors.bg1,
        border: Border(right: BorderSide(color: DashColors.glassBorder)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DashSpace.x3,
          Platform.isMacOS ? DashSpace.x2 : DashSpace.x4,
          DashSpace.x3,
          DashSpace.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DashSpace.x3, horizontal: DashSpace.x2),
              child: GlowText('DASH', style: DashType.title),
            ),
            const SizedBox(height: DashSpace.x2),
            for (final item in Shell._sections)
              _NavItem(
                icon: item.icon,
                label: item.label,
                selected: selected == item.section,
                onTap: () => ref.read(shellSectionProvider.notifier).select(item.section),
              ),
            const Spacer(),
            const _VaultBanner(),
          ],
        ),
      ),
    );
  }
}

class _VaultBanner extends ConsumerWidget {
  const _VaultBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultPath = ref.watch(vaultPathProvider).value;
    final index = ref.watch(indexProvider).value;
    if (vaultPath == null) return const SizedBox.shrink();

    final conflicts = index?.conflictedPaths.length ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: DashSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflicts > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: DashSpace.x2),
              child: Row(
                children: [
                  const DashIcon('warning', size: 14, color: DashColors.warning),
                  const SizedBox(width: DashSpace.x1),
                  Expanded(
                    child: Text(
                      '$conflicts conflicted ${conflicts == 1 ? 'copy' : 'copies'}',
                      style: DashType.label.copyWith(color: DashColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            p.basename(vaultPath),
            style: DashType.label,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? DashColors.accent : DashColors.text1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DashSpace.x1 / 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: DashMotion.hover,
            curve: DashMotion.curve,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
            decoration: BoxDecoration(
              color: widget.selected
                  ? DashColors.accentDim
                  : _hovering
                  ? DashColors.hover
                  : Colors.transparent,
              borderRadius: DashRadius.br,
              border: Border(
                left: BorderSide(
                  color: widget.selected ? DashColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                DashIcon(widget.icon, size: 18, color: color),
                const SizedBox(width: DashSpace.x2),
                Text(widget.label, style: DashType.label.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
