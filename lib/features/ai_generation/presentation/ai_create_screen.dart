import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_generation_result.dart';
import '../domain/generated_list.dart';
import 'ai_generation_providers.dart';
import 'generated_list_preview_screen.dart';

/// "Describe the list you need" -- the entry point for AI-assisted list
/// creation.
///
/// This screen only captures and submits the prompt. A successful
/// generation is immediately handed to [GeneratedListPreviewScreen] for
/// review; nothing here is persisted, and accepting the preview is only
/// wired up to the database starting in TASK-044.
class AiCreateScreen extends ConsumerStatefulWidget {
  const AiCreateScreen({super.key});

  @override
  ConsumerState<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends ConsumerState<AiCreateScreen> {
  final _controller = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;

  // Bumped on every submit/cancel so a late-arriving response from a
  // cancelled or superseded request is ignored instead of overwriting
  // state for whatever is happening now.
  int _requestId = 0;

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_isGenerating;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final prompt = _controller.text.trim();
    final requestId = ++_requestId;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final service = ref.read(listGenerationServiceProvider);
    final result = await service.generateList(prompt);

    if (!mounted || requestId != _requestId) return;

    switch (result) {
      case AiGenerationSuccess(:final list):
        setState(() => _isGenerating = false);
        await _showPreview(list);
      case AiGenerationError(:final failure):
        setState(() {
          _isGenerating = false;
          _errorMessage = failure.message;
        });
    }
  }

  Future<void> _showPreview(GeneratedList list) async {
    final accepted = await Navigator.of(context).push<GeneratedList>(
      MaterialPageRoute(
        builder: (_) => GeneratedListPreviewScreen(initial: list),
      ),
    );

    if (!mounted || accepted == null) return;

    // TASK-044 will persist `accepted` into the database and open the
    // new list; for now, acknowledge acceptance and reset the prompt.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('List accepted.')));
    setState(() => _controller.clear());
  }

  void _cancelGeneration() {
    setState(() {
      _requestId++;
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Describe the list you need',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_isGenerating,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'e.g. "Pack for a 3-day camping trip"',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          if (_isGenerating)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _cancelGeneration,
                  child: const Text('Cancel'),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('Make me a list'),
            ),
        ],
      ),
    );
  }
}
