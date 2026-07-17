import 'dart:io';

import 'package:path/path.dart' as p;

/// The only preset schema — Projects. Users create every other database
/// in-app.
const _projectsSchemaYaml = '''
name: Projects
folder: Projects
fields:
  - {name: title, type: text, required: true}
  - {name: status, type: select, options: [active, paused, done]}
  - {name: software, type: multiselect}
''';

const _settingsYaml = '''
journal_folder: Journal
attachments_folder: Attachments
''';

/// Creates a fresh vault folder structure + `.dash/` config at [rootPath].
Future<void> scaffoldVault(String rootPath) async {
  for (final folder in ['Journal', 'Databases', 'Projects', 'Attachments', p.join('.dash', 'databases')]) {
    await Directory(p.join(rootPath, folder)).create(recursive: true);
  }
  await File(p.join(rootPath, '.dash', 'settings.yaml')).writeAsString(_settingsYaml);
  await File(
    p.join(rootPath, '.dash', 'databases', 'projects.yaml'),
  ).writeAsString(_projectsSchemaYaml);
}
