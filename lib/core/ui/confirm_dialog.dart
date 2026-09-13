import 'package:flutter/material.dart';

/// Shows a confirmation dialog for a destructive action. Returns `true`
/// if the user confirmed, `false`/`null` otherwise. Every call site
/// today (delete list/section/template, clear completed) is genuinely
/// destructive, so the confirm action is always styled as a warning
/// rather than taking a flag no caller would ever set to `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
