import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_generation_result.dart';
import '../domain/generated_list.dart';
import 'ai_generation_providers.dart';

/// "Describe the list you need" -- the entry point for AI-assisted list
/// creation.
///
/// This screen only captures the prompt, submits it, and shows a minimal
/// summary of the result. Reviewing, editing, and explicitly accepting
/// the generated content into a real list is the dedicated preview flow
/// added in TASK-043/TASK-044; nothing here is persisted.
class AiCreateScreen extends ConsumerStatefulWidget {
  const AiCreateScreen({super.key});

  @override
  ConsumerState<AiCreateScreen> createState() => _AiCreateScreenState();
}

class _AiCreateScreenState extends ConsumerState<AiCreateScreen> {
  final _controller = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;
  GeneratedList? _result;

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
      _result = null;
    });

    final service = ref.read(listGenerationServiceProvider);
    final result = await service.generateList(prompt);

    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isGenerating = false;
      switch (result) {
        case AiGenerationSuccess(:final list):
          _result = list;
        case AiGenerationError(:final failure):
          _errorMessage = failure.message;
      }
    });
  }

  void _cancelGeneration() {
    setState(() {
      _requestId++;
      _isGenerating = false;
    });
  }

  void _startOver() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return _GeneratedSummary(list: result, onStartOver: _startOver);
    }

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

class _GeneratedSummary extends StatelessWidget {
  const _GeneratedSummary({required this.list, required this.onStartOver});

  final GeneratedList list;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final itemCount = list.sections.fold<int>(
      0,
      (sum, section) => sum + section.items.length,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              list.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('$itemCount item${itemCount == 1 ? '' : 's'} generated'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onStartOver,
              child: const Text('Start over'),
            ),
          ],
        ),
      ),
    );
  }
}
