import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/providers.dart';

/// Dev-only visual verification: built with
/// --dart-define=DASH_SHOT_DIR=dir (and DASH_SHOT_VAULT=vault), the app opens
/// the given vault, screenshots each shell section into the dir, then exits.
/// Inert in normal builds.
const shotDir = String.fromEnvironment('DASH_SHOT_DIR');
const _shotVault = String.fromEnvironment('DASH_SHOT_VAULT');

final shotBoundaryKey = GlobalKey();

Future<void> shotSetup() async {
  if (shotDir.isEmpty || _shotVault.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('vault_path', _shotVault);
}

Future<void> _shot(String name) async {
  await Future.delayed(const Duration(seconds: 2));
  final boundary =
      shotBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('$shotDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> shotRun(ProviderContainer container) async {
  if (shotDir.isEmpty) return;
  await Future.delayed(const Duration(seconds: 4));
  // Force the note editor into its rendered read view so the journal shot proves
  // Stage-B rendering (images, callouts, code fences, hidden markers).
  container.read(editorReadModeProvider.notifier).set(true);
  for (final section in ShellSection.values) {
    container.read(shellSectionProvider.notifier).select(section);
    await _shot(section.name);
  }
  final index = container.read(indexProvider).value;
  final slug = index?.entriesByDb.keys.firstWhere((s) => s != 'projects', orElse: () => '');
  if (slug != null && slug.isNotEmpty) {
    container.read(shellSectionProvider.notifier).select(ShellSection.databases);
    container.read(databasesNavProvider.notifier).showTable(slug);
    await _shot('db_table');
    final first = index!.entriesByDb[slug]!.first;
    container.read(databasesNavProvider.notifier).showEntry(slug, path: first.path);
    await _shot('db_entry');
  }
  if (index != null && index.projects.isNotEmpty) {
    container.read(shellSectionProvider.notifier).select(ShellSection.projects);
    container.read(projectsNavProvider.notifier).showDetail(index.projects.first.path);
    await _shot('projects_detail');
  }
  exit(0);
}
