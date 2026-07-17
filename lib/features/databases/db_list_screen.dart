import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_panel.dart';
import 'schema_editor.dart';

/// Gallery of user-defined databases (schema cards). Tapping one opens its
/// table; "New database" opens [showSchemaEditor].
class DbListScreen extends ConsumerWidget {
  const DbListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(indexProvider).value;
    final schemas =
        index?.schemas.entries.where((e) => e.key != 'projects').toList() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Databases', style: DashType.display),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => showSchemaEditor(context),
              icon: const DashIcon('add', size: 16, color: DashColors.bg0),
              label: const Text('New database'),
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x4),
        Expanded(
          child: schemas.isEmpty
              ? const EmptyState(
                  icon: 'database',
                  message: 'Nothing catalogued yet.',
                  subtitle: 'Create a database to get started.',
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    crossAxisSpacing: DashSpace.x3,
                    mainAxisSpacing: DashSpace.x3,
                    childAspectRatio: 2.4,
                  ),
                  itemCount: schemas.length,
                  itemBuilder: (context, i) {
                    final slug = schemas[i].key;
                    final schema = schemas[i].value;
                    final count = index?.entriesByDb[slug]?.length ?? 0;
                    return _DbCard(
                      name: schema.name,
                      count: count,
                      onTap: () => ref.read(databasesNavProvider.notifier).showTable(slug),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DbCard extends StatefulWidget {
  const _DbCard({required this.name, required this.count, required this.onTap});
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  State<_DbCard> createState() => _DbCardState();
}

class _DbCardState extends State<_DbCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DashMotion.duration,
          curve: DashMotion.curve,
          transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: DashRadius.br,
            border: Border.all(color: _hovering ? DashColors.accent.withValues(alpha: 0.4) : Colors.transparent),
          ),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashIcon('database', size: 24, color: _hovering ? DashColors.accent : DashColors.text1),
                const SizedBox(height: DashSpace.x2),
                Text(widget.name, style: DashType.title, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('${widget.count} ${widget.count == 1 ? 'entry' : 'entries'}', style: DashType.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
