import 'package:flutter/material.dart';

/// Prompts for a new template name, pre-filled with [initialName].
/// Returns the trimmed new name, or `null` if the user cancelled.
Future<String?> showRenameTemplateDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameTemplateDialog(initialName: initialName),
  );
}

class _RenameTemplateDialog extends StatefulWidget {
  const _RenameTemplateDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameTemplateDialog> createState() => _RenameTemplateDialogState();
}

class _RenameTemplateDialogState extends State<_RenameTemplateDialog> {
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
      title: const Text('Rename template'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
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
