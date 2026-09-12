import 'ai_generation_result.dart';

/// Provider-independent contract for turning a natural-language prompt
/// into a [GeneratedList] preview.
///
/// Implementations live in the data layer (e.g. a future OpenAI adapter
/// added in TASK-045) and are swapped in behind Riverpod providers.
/// Domain and UI code -- and all automated tests -- depend only on this
/// interface, never on a concrete provider, so no live provider
/// dependency leaks outside the adapter itself.
///
/// The same [AiGenerationResult] contract is reused for list modification
/// (TASK-050): a modification request is just a prompt that also carries
/// a snapshot of the existing list, and its result is validated and
/// previewed the same way as a fresh generation.
abstract class ListGenerationService {
  /// Requests a new list for [prompt]. Never throws for expected failure
  /// modes (network, timeout, provider error, invalid response) -- those
  /// are reported via [AiGenerationError] so callers don't need try/catch
  /// to handle the everyday failure paths.
  Future<AiGenerationResult> generateList(String prompt);
}
