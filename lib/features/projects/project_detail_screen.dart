import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_status.dart';
import '../../core/tasks.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/dash_icon.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/properties_sidebar.dart';
import '../databases/db_widgets.dart';
import '../databases/template_menu.dart';
import '../editor/editor.dart';
import '../editor/note_cover.dart';
import 'project_widgets.dart';

/// One project: header (title, status, software), a checklist view over the
/// body's `- [ ]` lines, and the full body in [NoteEditor] below. Both the
/// checklist and the editor are views over the same `DbEntryDoc.body` state —
/// toggling a task or editing text both just call `notifier.setBody`, so they
/// can never drift out of sync.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: 'projects', path: path);
    final schema = ref.watch(dbSchemaProvider('projects'));
    final doc = ref.watch(dbEntryProvider(key));
    final notifier = ref.read(dbEntryProvider(key).notifier);
    if (schema == null) return const SizedBox.shrink();

    const statusOptions = kProjectStatuses;
    final title = doc.value?.fields['title'] as String? ?? 'Untitled';
    final coverVal = doc.value?.fields['cover'];

    final header = NoteCoverHeader(
      cover: coverVal is String ? coverVal : null,
      coverY: (doc.value?.fields['coverY'] as num?)?.toDouble() ?? 0.5,
      onChanged: (v) => notifier.setField('cover', v),
      onReposition: (y) => notifier.setField('coverY', y),
      title: Row(
        children: [
          BackNavButton(onTap: () => ref.read(projectsNavProvider.notifier).showList()),
          const SizedBox(width: DashSpace.x2),
          Expanded(child: Text(title, style: DashType.display, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    final banner = doc.value?.changedOnDisk ?? false
        ? ChangedOnDiskBanner(onReload: notifier.reload, message: 'This project changed on disk while you were editing.')
        : null;

    return switch (doc) {
      AsyncData(:final value) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  ?banner,
                  Align(
                    alignment: Alignment.centerRight,
                    child: TemplateMenu(
                      fields: value.fields,
                      body: value.body,
                      onSetField: notifier.setField,
                      onSetBody: notifier.setBody,
                    ),
                  ),
                  const SizedBox(height: DashSpace.x3),
                  Expanded(
                    child: _Body(value: value, onSetBody: notifier.setBody),
                  ),
                ],
              ),
            ),
            PropertiesSidebar(children: [
              PropertyGroup(
                label: 'Status',
                child: _StatusDropdown(
                  value: value.fields['status'] as String? ?? 'active',
                  options: statusOptions,
                  onChanged: (v) => notifier.setField('status', v),
                ),
              ),
              PropertyGroup(
                label: 'Software',
                child: SoftwareChipsEditor(
                  value: (value.fields['software'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
                  onChanged: (v) => notifier.setField('software', v),
                ),
              ),
            ]),
          ],
        ),
      AsyncError(:final error) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            ?banner,
            const SizedBox(height: DashSpace.x3),
            Expanded(child: Center(child: Text('$error', style: DashType.body.copyWith(color: DashColors.danger)))),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: DashSpace.x3),
            Expanded(child: Center(child: CircularProgressIndicator(color: DashColors.accent))),
          ],
        ),
    };
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.value, required this.onSetBody});
  final DbEntryDoc value;
  final ValueChanged<String> onSetBody;

  @override
  Widget build(BuildContext context) {
    final body = value.body;
    final tasks = parseTasks(body);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Tasks', style: DashType.heading),
                  const SizedBox(width: DashSpace.x2),
                  if (tasks.isNotEmpty)
                    Text(
                      '${tasks.where((t) => t.checked).length}/${tasks.length}',
                      style: DashType.mono.copyWith(color: DashColors.text1),
                    ),
                ],
              ),
              const SizedBox(height: DashSpace.x2),
              if (tasks.isEmpty)
                Text('No tasks yet.', style: DashType.small)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (context, i) {
                      final t = tasks[i];
                      return _TaskRow(item: t, onToggle: () => onSetBody(toggleTask(body, t.lineIndex)));
                    },
                  ),
                ),
              const SizedBox(height: DashSpace.x2),
              _QuickAddTask(onAdd: (text) => onSetBody(appendTask(body, text))),
            ],
          ),
        ),
        const SizedBox(height: DashSpace.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes', style: DashType.heading),
              const SizedBox(height: DashSpace.x2),
              Expanded(
                child: NoteEditor(
                  key: ValueKey(value.path),
                  initialText: body,
                  onChanged: onSetBody,
                  centered: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item, required this.onToggle});
  final TaskItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: DashRadius.br,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            DashCheckbox(value: item.checked, onChanged: (_) => onToggle()),
            const SizedBox(width: DashSpace.x2),
            Expanded(
              child: Text(
                item.text,
                style: DashType.body.copyWith(
                  color: item.checked ? DashColors.text2 : DashColors.text0,
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddTask extends StatefulWidget {
  const _QuickAddTask({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  State<_QuickAddTask> createState() => _QuickAddTaskState();
}

class _QuickAddTaskState extends State<_QuickAddTask> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String v) {
    if (v.trim().isEmpty) return;
    widget.onAdd(v);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DashIcon('add', size: 16, color: DashColors.text2),
        const SizedBox(width: DashSpace.x2),
        Expanded(
          child: TextField(
            controller: _controller,
            style: DashType.body,
            decoration: const InputDecoration(isDense: true, hintText: 'Add a task…'),
            onSubmitted: _submit,
          ),
        ),
      ],
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DashDropdown<String>(
      value: value,
      options: [for (final o in options) DashOption(o, o, chipColor: statusColor(o))],
      onChanged: onChanged,
      menuWidth: 140,
      triggerBuilder: (context, open) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(value),
          const SizedBox(width: 2),
          AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: DashMotion.duration,
            curve: DashMotion.curve,
            child: DashIcon('expand_more', size: 16, color: open ? DashColors.accent : DashColors.text2),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: DashRadius.br),
      child: Text(status, style: DashType.small.copyWith(color: color, fontWeight: FontWeight.w500)),
    );
  }
}
