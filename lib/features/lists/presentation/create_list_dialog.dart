import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

/// Shows a dialog for creating a blank list. Returns the created
/// [ListRecord], or `null` if the user cancelled.
Future<ListRecord?> showCreateListDialog(BuildContext context) {
  return showDialog<ListRecord>(
    context: context,
    builder: (_) => const CreateListDialog(),
  );
}

class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({super.key});

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_submitting;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    final repository = ref.read(listRepositoryProvider);
    final list = await repository.createList(title: _controller.text);

    if (!mounted) return;
    Navigator.of(context).pop(list);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New list'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'List title'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
