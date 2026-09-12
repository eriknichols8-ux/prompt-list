import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/ai_generation_failure.dart';
import '../domain/ai_generation_result.dart';
import '../domain/generated_list.dart';
import '../domain/generated_list_validator.dart';
import '../domain/list_generation_service.dart';

/// System prompt instructing the model to return exactly the canonical
/// structure defined in `docs/AI_CONTRACT.md`, and nothing else.
const _generationSystemPrompt = '''
You turn a short user request into a checklist. Respond with ONLY a
single JSON object -- no markdown, no commentary -- matching this
shape exactly:

{
  "title": "string, required, a short useful title",
  "description": "string or null, optional, one short sentence",
  "sections": [
    {
      "title": "string or null; use null for a single flat list",
      "items": [
        { "text": "string, required, one checklist item" }
      ]
    }
  ]
}

Rules:
- Only split into multiple sections when it genuinely helps organize
  the list; a simple request should get one section with a null title.
- Never include completion state, IDs, or sort order -- the app
  assigns those.
- Keep item text concise and free of numbering or bullet characters.
- If the request is ambiguous or time-sensitive (e.g. involves facts
  that could be incomplete or outdated), still do your best and keep
  the list reasonably sized; the app will show it for review before
  anything is saved.
''';

/// System prompt for modifying an existing list. Uses the same output
/// shape as generation (see `_generationSystemPrompt`).
const _modificationSystemPrompt = '''
You are given an existing checklist as JSON, plus an instruction
describing how to change it. Respond with ONLY a single JSON object --
no markdown, no commentary -- representing the FULL updated list,
matching this shape exactly:

{
  "title": "string, required, a short useful title",
  "description": "string or null, optional, one short sentence",
  "sections": [
    {
      "title": "string or null; use null for a single flat list",
      "items": [
        { "text": "string, required, one checklist item" }
      ]
    }
  ]
}

Rules:
- Apply the instruction to the existing list; keep everything else
  the same unless the instruction implies otherwise.
- Return the complete list, not just the changed parts.
- Never include completion state, IDs, or sort order -- the app
  assigns those and decides separately what stays checked.
- Keep item text concise and free of numbering or bullet characters.
''';

/// [ListGenerationService] backed by the OpenAI Chat Completions API.
///
/// This is the development provider adapter described in
/// `docs/ARCHITECTURE.md`'s "AI Provider Security" section: the API key
/// is supplied by the caller (see `main.dart`, which reads it from a
/// non-committed local `.env` via `--dart-define-from-file`) and is
/// never hard-coded, logged, or embedded as a distributable-build
/// default. Every transport, provider, and malformed-response failure
/// mode is mapped to a typed [AiGenerationFailure] rather than thrown,
/// and the response body is always run through [GeneratedListValidator]
/// before anything reaches the preview screen.
class OpenAiListGenerationService implements ListGenerationService {
  OpenAiListGenerationService({
    required this.apiKey,
    http.Client? client,
    this.model = 'gpt-4o-mini',
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _validator = GeneratedListValidator();

  static final _endpoint = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );

  final String apiKey;
  final http.Client _client;
  final GeneratedListValidator _validator;
  final String model;
  final Duration timeout;

  @override
  Future<AiGenerationResult> generateList(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.invalidPrompt,
          'Prompt must not be empty.',
        ),
      );
    }

    return _requestAndValidate([
      {'role': 'system', 'content': _generationSystemPrompt},
      {'role': 'user', 'content': trimmed},
    ]);
  }

  @override
  Future<AiGenerationResult> modifyList({
    required GeneratedList snapshot,
    required String instruction,
  }) async {
    final trimmed = instruction.trim();
    if (trimmed.isEmpty) {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.invalidPrompt,
          'Instruction must not be empty.',
        ),
      );
    }

    final userMessage =
        'Existing list:\n${jsonEncode(snapshot.toJson())}\n\n'
        'Instruction: $trimmed';

    return _requestAndValidate([
      {'role': 'system', 'content': _modificationSystemPrompt},
      {'role': 'user', 'content': userMessage},
    ]);
  }

  /// Sends [messages] to the Chat Completions endpoint and validates the
  /// resulting message content, mapping every transport/provider/parse
  /// failure to a typed [AiGenerationFailure] along the way.
  Future<AiGenerationResult> _requestAndValidate(
    List<Map<String, String>> messages,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'response_format': {'type': 'json_object'},
              'messages': messages,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.timeout,
          'The request took too long. Please try again.',
        ),
      );
    } catch (e) {
      return AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.network,
          'Could not reach the AI provider: $e',
        ),
      );
    }

    if (response.statusCode == 429) {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.rateLimited,
          'The AI provider is busy right now. Please try again shortly.',
        ),
      );
    }
    if (response.statusCode != 200) {
      return AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.providerError,
          'The AI provider returned an error '
          '(status ${response.statusCode}).',
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.invalidResponse,
          'The AI provider response was not valid JSON.',
        ),
      );
    }

    final content = _extractMessageContent(decoded);
    if (content == null) {
      return const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.invalidResponse,
          'The AI provider response was missing message content.',
        ),
      );
    }

    return _validator.validate(content);
  }

  /// Pulls `choices[0].message.content` out of a decoded Chat
  /// Completions response, or `null` if the shape doesn't match.
  String? _extractMessageContent(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;
    final message = first['message'];
    if (message is! Map<String, dynamic>) return null;
    final content = message['content'];
    return content is String ? content : null;
  }
}
