import 'package:flutter/material.dart';
import 'package:promptlist/core/database/app_database.dart';

/// Lets the user pick a section (other than the item's current one)
/// to move an item into. Returns the chosen section's ID, or `null` if
/// the user cancelled.
Future<String?> showMoveToSectionDialog(
  BuildContext context, {
  required List<SectionRecord> sections,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Move to section'),
      children: [
        for (final section in sections)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(section.id),
            child: Text(section.title ?? 'Untitled section'),
          ),
      ],
    ),
  );
}
