import '../domain/ai_generation_failure.dart';
import '../domain/ai_generation_result.dart';
import '../domain/generated_list.dart';
import '../domain/list_generation_service.dart';

/// Deterministic [ListGenerationService] used by widget/integration tests
/// and available as a local fallback when no provider key is configured.
///
/// By default it turns a prompt into a small, predictable list so tests
/// never depend on a live model. Callers can override [onGenerate] to
/// exercise specific success or failure scenarios.
class FakeListGenerationService implements ListGenerationService {
  FakeListGenerationService({this.onGenerate});

  /// When set, replaces the default deterministic behavior entirely.
  final AiGenerationResult Function(String prompt)? onGenerate;

  @override
  Future<AiGenerationResult> generateList(String prompt) async {
    final override = onGenerate;
    if (override != null) return override(prompt);

    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.invalidPrompt,
          'Prompt must not be empty.',
        ),
      );
    }

    return AiGenerationSuccess(
      GeneratedList(
        title: trimmed,
        description: 'Generated from: "$trimmed"',
        sections: [
          GeneratedSection(
            items: const [
              GeneratedItem(text: 'First item'),
              GeneratedItem(text: 'Second item'),
              GeneratedItem(text: 'Third item'),
            ],
          ),
        ],
      ),
    );
  }
}
