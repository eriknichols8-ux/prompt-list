import 'package:flutter/material.dart';

/// Secondary destination for app preferences and AI configuration/status.
///
/// Reached from the app bar rather than the primary navigation so it does
/// not clutter the main Lists/Templates/AI Create workflow.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings')),
    );
  }
}
