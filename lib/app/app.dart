import 'package:flutter/material.dart';

import 'root_shell.dart';

/// Root widget for the PromptList application shell.
class PromptListApp extends StatelessWidget {
  const PromptListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C4A2E)),
      ),
      home: const RootShell(),
    );
  }
}
