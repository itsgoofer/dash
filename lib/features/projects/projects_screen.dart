import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'project_detail_screen.dart';
import 'projects_list_screen.dart';

/// Top-level Projects section: list → detail, switched by [projectsNavProvider]
/// — mirrors [DatabasesScreen].
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(projectsNavProvider);
    final key = switch (view) {
      ProjectsListView() => 'list',
      ProjectDetailView(:final path) => 'detail-$path',
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(key),
        child: switch (view) {
          ProjectsListView() => const ProjectsListScreen(),
          ProjectDetailView(:final path) => ProjectDetailScreen(path: path),
        },
      ),
    );
  }
}
