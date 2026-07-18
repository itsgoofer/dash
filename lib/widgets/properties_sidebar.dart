import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/dash_theme.dart';
import 'dash_controls.dart';

/// App-wide collapse state for the note properties rail — shared so the choice
/// sticks as you move between notes.
class _PropsCollapsed extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final propertiesCollapsedProvider = NotifierProvider<_PropsCollapsed, bool>(_PropsCollapsed.new);

/// Notion-style right rail: a note's properties stacked vertically, collapsible
/// to a thin strip via the chevron. Screens pass their own property widgets as
/// [children]; the rail supplies the chrome, spacing and scroll.
class PropertiesSidebar extends ConsumerWidget {
  const PropertiesSidebar({super.key, required this.children, this.title = 'Properties', this.width = 288});

  final List<Widget> children;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(propertiesCollapsedProvider);
    final toggle = ref.read(propertiesCollapsedProvider.notifier).toggle;

    return AnimatedContainer(
      duration: DashMotion.duration,
      curve: DashMotion.curve,
      width: collapsed ? 40 : width,
      decoration: BoxDecoration(border: Border(left: BorderSide(color: DashColors.glassBorder))),
      child: collapsed
          ? Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: DashSpace.x1),
                child: DashIconBtn('chevron_left', tooltip: 'Show properties', onTap: toggle),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(left: DashSpace.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title.toUpperCase(),
                            style: DashType.hudLabel.copyWith(fontSize: 10.5, letterSpacing: 1.5, color: DashColors.text2)),
                      ),
                      DashIconBtn('chevron_right', tooltip: 'Hide properties', onTap: toggle),
                    ],
                  ),
                  const SizedBox(height: DashSpace.x3),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(height: DashSpace.x4),
                            children[i],
                          ],
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

/// A titled group inside the [PropertiesSidebar] — small caption over content,
/// so heterogeneous property widgets read as a tidy vertical stack.
class PropertyGroup extends StatelessWidget {
  const PropertyGroup({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DashType.label.copyWith(color: DashColors.text2)),
        const SizedBox(height: DashSpace.x2),
        child,
      ],
    );
  }
}
