import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

const _minSize = Size(1100, 720);
const _defaultSize = Size(1440, 900);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
  }

  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: _defaultSize,
    minimumSize: _minSize,
    center: true,
    title: 'Dash',
    titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: DashApp()));
}
