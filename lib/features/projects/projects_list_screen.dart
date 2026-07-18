import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/frontmatter.dart';
import '../../core/models/note.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_chip.dart';
import '../../widgets/dash_controls.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_panel.dart';
import 'project_widgets.dart';

/// Card gallery of every project note (`index.projects`). "New project"
/// prompts for a title, creates `Projects/<Title>.md`, and opens it.
class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final title = await _promptTitle(context);
    if (title == null) return;
    final root = ref.read(vaultPathProvider).value;
    if (root == null) return;

    final sanitized = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final abs = p.join(root, 'Projects', '$sanitized.md');
    final content = Frontmatter.serialize(
      {'type': 'project', 'title': title, 'status': 'active'},
      '',
      keyOrder: const ['type', 'title', 'status', 'software'],
    );
    await ref.read(vaultFsProvider).writeNote(abs, content);
    ref.read(projectsNavProvider.notifier).showDetail('Projects/$sanitized.md');
  }

  Future<String?> _promptTitle(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DashColors.bg1,
        shape: RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder)),
        title: const Text('New project', style: DashType.heading),
        content: SizedBox(
          width: 320,
          child: DashTextField(
            controller: controller,
            autofocus: true,
            hint: 'Project title',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(indexProvider).value?.projects ?? const <NoteMeta>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Projects', style: DashType.display),
            const Spacer(),
            DashButton(
              'New project',
              icon: 'add',
              kind: DashButtonKind.primary,
              onTap: () => _createProject(context, ref),
            ),
          ],
        ),
        const SizedBox(height: DashSpace.x4),
        Expanded(
          child: projects.isEmpty
              ? const EmptyState(
                  icon: 'deployed_code',
                  message: 'Nothing in flight yet.',
                  subtitle: 'Start a project to see it here.',
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    crossAxisSpacing: DashSpace.x3,
                    mainAxisSpacing: DashSpace.x3,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, i) => _ProjectCard(
                    project: projects[i],
                    onTap: () => ref.read(projectsNavProvider.notifier).showDetail(projects[i].path),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProjectCard extends ConsumerStatefulWidget {
  const _ProjectCard({required this.project, required this.onTap});
  final NoteMeta project;
  final VoidCallback onTap;

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final fm = widget.project.frontmatter;
    final title = fm['title'] as String? ?? p.basenameWithoutExtension(widget.project.path);
    final status = fm['status'] as String? ?? 'active';
    final software = (fm['software'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final counts = ref.watch(projectTaskCountsProvider(widget.project.path)).value;

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
                    Expanded(child: Text(title, style: DashType.title, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: DashSpace.x1),
                    DashChip(status, color: statusColor(status)),
                  ],
                ),
                const SizedBox(height: DashSpace.x2),
                if (software.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [for (final s in software) DashChip(s, color: DashChip.optionColor(s))],
                  ),
                const Spacer(),
                if (counts != null && counts.total > 0) ...[
                  Row(
                    children: [
                      Text('${counts.done}/${counts.total}', style: DashType.mono.copyWith(color: DashColors.text1)),
                      const SizedBox(width: DashSpace.x2),
                      Expanded(child: TaskProgressBar(value: counts.total == 0 ? 0 : counts.done / counts.total)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
