import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/shell/shell.dart';
import 'state/providers.dart';
import 'theme/dash_theme.dart';

class DashApp extends ConsumerWidget {
  const DashApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accentProvider); // rebuild theme when the accent changes
    return MaterialApp(
      title: 'Dash',
      debugShowCheckedModeBanner: false,
      theme: buildDashTheme(),
      darkTheme: buildDashTheme(),
      themeMode: ThemeMode.dark,
      home: const AppRoot(),
    );
  }
}
