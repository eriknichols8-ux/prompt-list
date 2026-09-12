import 'ai_generation_failure.dart';
import 'generated_list.dart';

/// The outcome of a single generation or modification attempt.
///
/// Modeled as a sealed class rather than throwing so callers -- the
/// preview screen in particular -- are forced to handle both the success
/// and failure paths explicitly.
sealed class AiGenerationResult {
  const AiGenerationResult();
}

/// The provider returned a payload that satisfied the canonical
/// generated-list contract.
class AiGenerationSuccess extends AiGenerationResult {
  const AiGenerationSuccess(this.list);

  final GeneratedList list;
}

/// Generation or modification could not produce a usable [GeneratedList].
class AiGenerationError extends AiGenerationResult {
  const AiGenerationError(this.failure);

  final AiGenerationFailure failure;
}
