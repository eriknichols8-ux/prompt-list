import 'package:flutter/material.dart';

/// Prompts for a natural-language instruction describing how to change
/// the current list (e.g. "alphabetize this" or "add the Disney+
/// shows"). Returns the trimmed instruction, or `null` if the user
/// cancelled.
Future<String?> showAiModifyListDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _AiModifyListDialog(),
  );
}

class _AiModifyListDialog extends StatefulWidget {
  const _AiModifyListDialog();

  @override
  State<_AiModifyListDialog> createState() => _AiModifyListDialogState();
}

class _AiModifyListDialogState extends State<_AiModifyListDialog> {
  final _controller = TextEditingController();

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
      title: const Text('Ask AI to change this list'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'e.g. "alphabetize this" or "add the Disney+ shows"',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Ask AI'),
        ),
      ],
    );
  }
}
