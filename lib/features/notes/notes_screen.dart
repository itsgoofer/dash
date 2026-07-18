import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/models/note.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/properties_sidebar.dart';
import '../databases/db_widgets.dart';
import '../editor/backlinks_panel.dart';
import '../editor/editor.dart';

final _mtimeFmt = DateFormat('MMM d, yyyy');

String _titleOf(NoteMeta note) {
  final fm = note.frontmatter['title'] as String?;
  return (fm != null && fm.isNotEmpty) ? fm : p.basenameWithoutExtension(note.path);
}

/// Top-level Notes section: switches between the searchable gallery and a
/// plain-note editor, mirroring ProjectsScreen/DatabasesScreen.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(notesNavProvider);
    return switch (view) {
      NotesListView() => const _NotesListScreen(),
      NoteDetailView(:final path) => _NoteDetailScreen(path: path),
    };
  }
}

class _NotesListScreen extends ConsumerStatefulWidget {
  const _NotesListScreen();

  @override
  ConsumerState<_NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<_NotesListScreen> {
  String _query = '';

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final title = await _promptTitle(context);
    if (title == null) return;
    final root = ref.read(vaultPathProvider).value;
    if (root == null) return;

    final sanitized = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final rel = 'Notes/$sanitized.md';
    await ref.read(vaultFsProvider).writeNote(p.join(root, rel), '');
    ref.read(notesNavProvider.notifier).showDetail(rel);
  }

  Future<String?> _promptTitle(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DashColors.bg1,
        shape: RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder)),
        title: const Text('New note', style: DashType.heading),
        content: SizedBox(
          width: 320,
          child: DashTextField(
            controller: controller,
            autofocus: true,
            hint: 'Note title',
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          DashButton('Cancel', onTap: () => Navigator.pop(context)),
          DashButton('Create',
              kind: DashButtonKind.primary, onTap: () => Navigator.pop(context, controller.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesListProvider);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty ? notes : notes.where((n) => _titleOf(n).toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Notes', style: DashType.display),
            const Spacer(),
            DashButton(
              'New note',
              icon: 'add',
              kind: DashButtonKind.primary,
              onTap: () => _createNote(context, ref),
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x3),
        DashTextField(
          hint: 'Search notes…',
          icon: 'search',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: DashSpace.x4),
        Expanded(
          child: notes.isEmpty
              ? const EmptyState(
                  icon: 'edit',
                  message: 'No notes yet.',
                  subtitle: 'Create a note to get started.',
                )
              : filtered.isEmpty
                  ? const EmptyState(icon: 'search', message: 'No matches.')
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        crossAxisSpacing: DashSpace.x3,
                        mainAxisSpacing: DashSpace.x3,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _NoteCard(
                        note: filtered[i],
                        onTap: () => ref.read(notesNavProvider.notifier).showDetail(filtered[i].path),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({required this.note, required this.onTap});
  final NoteMeta note;
  final VoidCallback onTap;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_titleOf(widget.note), style: DashType.title, overflow: TextOverflow.ellipsis, maxLines: 2),
                const SizedBox(height: DashSpace.x1),
                Text(_mtimeFmt.format(widget.note.mtime), style: DashType.small.copyWith(color: DashColors.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteDetailScreen extends ConsumerWidget {
  const _NoteDetailScreen({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(plainNoteProvider(path));
    final notifier = ref.read(plainNoteProvider(path).notifier);
    final title = doc.value?.title ?? p.basenameWithoutExtension(path);

    final header = Row(
      children: [
        BackNavButton(onTap: () => ref.read(notesNavProvider.notifier).showList()),
        const SizedBox(width: DashSpace.x2),
        Expanded(child: Text(title, style: DashType.display, overflow: TextOverflow.ellipsis)),
      ],
    );
    final banner = doc.value?.changedOnDisk ?? false
        ? ChangedOnDiskBanner(onReload: notifier.reload, message: 'This note changed on disk while you were editing.')
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              ?banner,
              const SizedBox(height: DashSpace.x4),
              switch (doc) {
                AsyncData(:final value) => Expanded(
                    child:
                        NoteEditor(key: ValueKey(path), initialText: value.body, onChanged: notifier.setBody, centered: true),
                  ),
                AsyncError(:final error) =>
                  Expanded(child: Center(child: Text('$error', style: DashType.body.copyWith(color: DashColors.danger)))),
                _ => Expanded(child: Center(child: CircularProgressIndicator(color: DashColors.accent))),
              },
            ],
          ),
        ),
        PropertiesSidebar(children: [BacklinksPanel(path: path)]),
      ],
    );
  }
}
