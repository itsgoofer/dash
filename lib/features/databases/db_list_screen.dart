import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/db_schema.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_panel.dart';
import 'schema_editor.dart';

/// Gallery of user-defined databases (schema cards). Tapping one opens its
/// table; hover for edit/delete; "New database" opens [showSchemaEditor].
class DbListScreen extends ConsumerWidget {
  const DbListScreen({super.key});

  Future<void> _deleteDb(BuildContext context, WidgetRef ref, String slug, DbSchema schema, int count) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete database?',
      message: 'This permanently deletes "${schema.name}" — its schema and '
          '$count ${count == 1 ? 'entry' : 'entries'} on disk.',
    );
    if (!ok) return;
    final root = ref.read(vaultPathProvider).value;
    if (root == null) return;
    final fs = ref.read(vaultFsProvider);
    await fs.deleteFolder(p.join(root, schema.folder));
    await fs.deleteNote(p.join(root, '.dash', 'databases', '$slug.yaml'));
  }

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
            DashButton(
              'New database',
              icon: 'add',
              kind: DashButtonKind.primary,
              onTap: () => showSchemaEditor(context),
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
                      onEdit: () => showSchemaEditor(context, slug: slug),
                      onDelete: () => _deleteDb(context, ref, slug, schema, count),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DbCard extends StatefulWidget {
  const _DbCard({
    required this.name,
    required this.count,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                Row(
                  children: [
                    DashIcon('database', size: 24, color: _hovering ? DashColors.accent : DashColors.text1),
                    const Spacer(),
                    if (_hovering) ...[
                      DashIconBtn('edit', size: 14, tooltip: 'Edit database', onTap: widget.onEdit),
                      DashIconBtn('delete',
                          size: 14, color: DashColors.danger, tooltip: 'Delete database', onTap: widget.onDelete),
                    ],
                  ],
                ),
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
