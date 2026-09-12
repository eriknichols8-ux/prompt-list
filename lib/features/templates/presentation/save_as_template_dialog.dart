import 'package:flutter/material.dart';

/// Prompts for a template name, pre-filled with [initialName]. Returns
/// the trimmed name, or `null` if the user cancelled.
Future<String?> showSaveAsTemplateDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SaveAsTemplateDialog(initialName: initialName),
  );
}

class _SaveAsTemplateDialog extends StatefulWidget {
  const _SaveAsTemplateDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveAsTemplateDialog> createState() => _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends State<_SaveAsTemplateDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as template'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Template name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
