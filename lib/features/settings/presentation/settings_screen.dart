import 'package:flutter/material.dart';

/// Secondary destination for app preferences and AI configuration/status.
///
/// Reached from the app bar rather than the primary navigation so it does
/// not clutter the main Lists/Templates/AI Create workflow. Per
/// PRODUCT_SPEC.md section 4, this is honestly a placeholder --- no
/// preferences exist to configure yet, so the screen says so plainly
/// instead of a bare, unstyled "Settings" label that reads as broken
/// rather than intentional.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Nothing to configure yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'PromptList works fully offline with no setup required. '
                'Preferences, like AI provider status, will appear here '
                'as they are added.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
