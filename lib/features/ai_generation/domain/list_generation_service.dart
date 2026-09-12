import 'ai_generation_result.dart';
import 'generated_list.dart';

/// Provider-independent contract for turning a natural-language prompt
/// into a [GeneratedList] preview, and for proposing changes to an
/// existing list from an instruction.
///
/// Implementations live in the data layer (e.g. the OpenAI adapter added
/// in TASK-045) and are swapped in behind Riverpod providers. Domain and
/// UI code -- and all automated tests -- depend only on this interface,
/// never on a concrete provider, so no live provider dependency leaks
/// outside the adapter itself.
abstract class ListGenerationService {
  /// Requests a new list for [prompt]. Never throws for expected failure
  /// modes (network, timeout, provider error, invalid response) -- those
  /// are reported via [AiGenerationError] so callers don't need try/catch
  /// to handle the everyday failure paths.
  Future<AiGenerationResult> generateList(String prompt);

  /// Requests a change to an existing list: [snapshot] is a normalized
  /// snapshot of the list's current title/description/sections/items
  /// (see `docs/AI_CONTRACT.md`'s Modification Contract), and
  /// [instruction] is the user's natural-language request (e.g.
  /// "alphabetize this" or "add the Disney+ shows").
  ///
  /// The result reuses the exact same [AiGenerationResult]/[GeneratedList]
  /// contract as [generateList] -- a modification is validated and
  /// previewed the same way as a fresh generation, and [snapshot] itself
  /// is never mutated or persisted by this call. The AI never decides
  /// persisted completion state; matching which items can safely keep
  /// their existing completion is application logic applied when the
  /// result is later accepted (TASK-052).
  Future<AiGenerationResult> modifyList({
    required GeneratedList snapshot,
    required String instruction,
  });
}
