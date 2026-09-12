/// Categories of failure an AI generation or modification attempt can
/// produce. The UI maps these to understandable, typed messaging rather
/// than surfacing raw provider/network errors (see TASK-046).
enum AiGenerationFailureType {
  /// The user-supplied prompt failed local validation (empty, too long).
  invalidPrompt,

  /// The request could not reach the provider (offline, DNS, etc).
  network,

  /// The provider did not respond in time.
  timeout,

  /// The provider reported a rate limit; retry later.
  rateLimited,

  /// The provider returned an error response.
  providerError,

  /// The provider responded, but the payload did not satisfy the
  /// canonical generated-list contract (see TASK-041's validator).
  invalidResponse,

  /// Anything not covered by a more specific category above.
  unknown,
}

/// A typed failure produced by a [ListGenerationService] implementation.
///
/// Never persisted, and never used as a substitute for validated content:
/// a failure always means no [GeneratedList] is available for preview.
class AiGenerationFailure {
  const AiGenerationFailure(this.type, this.message);

  final AiGenerationFailureType type;
  final String message;

  @override
  String toString() => 'AiGenerationFailure(${type.name}: $message)';
}
