import 'package:flutter/material.dart';

/// Prompts for a section title. Unlike list/item text, a blank title
/// is valid (an untitled section), so Save is always enabled. Returns
/// the trimmed title (possibly empty), or `null` if the user
/// cancelled.
Future<String?> showSectionDialog(
  BuildContext context, {
  required String dialogTitle,
  String initialTitle = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _SectionDialog(dialogTitle: dialogTitle, initialTitle: initialTitle),
  );
}

class _SectionDialog extends StatefulWidget {
  const _SectionDialog({required this.dialogTitle, required this.initialTitle});

  final String dialogTitle;
  final String initialTitle;

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Section title (optional)'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
