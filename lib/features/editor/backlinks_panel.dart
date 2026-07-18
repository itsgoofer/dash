import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/note.dart';
import '../../state/navigation.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/properties_sidebar.dart';

String _typeIcon(NoteType type) => switch (type) {
      NoteType.journal => 'book_2',
      NoteType.db => 'database',
      NoteType.project => 'deployed_code',
      NoteType.note => 'edit',
    };

String _title(NoteMeta note) {
  final t = note.frontmatter['title'] as String?;
  return (t != null && t.isNotEmpty) ? t : p.basenameWithoutExtension(note.path);
}

/// Sidebar section listing notes that `[[wikilink]]` to the current note.
class BacklinksPanel extends ConsumerWidget {
  const BacklinksPanel({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(backlinksProvider(path));
    if (links.isEmpty) return const SizedBox.shrink();

    return PropertyGroup(
      label: 'Backlinks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final note in links) _BacklinkRow(note: note)],
      ),
    );
  }
}

class _BacklinkRow extends ConsumerStatefulWidget {
  const _BacklinkRow({required this.note});
  final NoteMeta note;

  @override
  ConsumerState<_BacklinkRow> createState() => _BacklinkRowState();
}

class _BacklinkRowState extends ConsumerState<_BacklinkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openNote(ref, widget.note),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x1, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? DashColors.hover : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              DashIcon(_typeIcon(widget.note.type), size: 14, color: DashColors.text1),
              const SizedBox(width: DashSpace.x2),
              Expanded(child: Text(_title(widget.note), style: DashType.small, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
