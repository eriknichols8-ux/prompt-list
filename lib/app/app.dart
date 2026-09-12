import 'package:flutter/material.dart';

import 'root_shell.dart';

/// The terracotta seed driving both the light and dark color schemes,
/// deliberately chosen to avoid the generic Material blue/purple look
/// (see CLAUDE.md's Visual Design Direction).
const _seedColor = Color(0xFF9C4A2E);

/// Root widget for the PromptList application shell.
///
/// Every screen in this app reads colors exclusively through
/// `Theme.of(context).colorScheme` (no hard-coded `Color`/`Colors.*`
/// values anywhere else in `lib/`), so both schemes below are the only
/// place contrast needs to be reasoned about; everything downstream
/// follows automatically. `themeMode` is left at its default
/// (`ThemeMode.system`) so the app follows the platform's light/dark
/// setting without any extra wiring.
class PromptListApp extends StatelessWidget {
  const PromptListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const RootShell(),
    );
  }
}
