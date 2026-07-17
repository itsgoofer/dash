import 'package:flutter/material.dart';

import 'features/shell/shell.dart';
import 'theme/dash_theme.dart';

class DashApp extends StatelessWidget {
  const DashApp({super.key});

  @override
  Widget build(BuildContext context) {
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
