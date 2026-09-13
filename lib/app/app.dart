import 'package:flutter/material.dart';

import 'root_shell.dart';
import 'theme.dart';

/// Root widget for the PromptList application shell.
///
/// Every screen in this app reads colors and shapes exclusively through
/// `Theme.of(context)` (no hard-coded `Color`/`Colors.*` values or
/// one-off shapes anywhere else in `lib/`), so [PromptListTheme] is the
/// only place visual identity needs to be reasoned about; everything
/// downstream follows automatically. `themeMode` is left at its default
/// (`ThemeMode.system`) so the app follows the platform's light/dark
/// setting without any extra wiring.
class PromptListApp extends StatelessWidget {
  const PromptListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptList',
      debugShowCheckedModeBanner: false,
      theme: PromptListTheme.light,
      darkTheme: PromptListTheme.dark,
      home: const RootShell(),
    );
  }
}
