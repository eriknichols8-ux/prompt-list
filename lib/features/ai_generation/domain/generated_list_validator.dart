import 'dart:convert';

import 'ai_generation_failure.dart';
import 'ai_generation_result.dart';
import 'generated_list.dart';

/// Converts raw provider output into a validated [GeneratedList],
/// implementing the canonical contract and limits documented in
/// `docs/AI_CONTRACT.md`.
///
/// AI output is untrusted external data: this validator never guesses
/// at malformed input. It either accepts a payload that fully satisfies
/// the contract, or returns a typed [AiGenerationError] with
/// [AiGenerationFailureType.invalidResponse] describing exactly what was
/// wrong. It does not invent missing text, merge items, or drop content
/// to make an invalid payload "work".
class GeneratedListValidator {
  static const titleMaxLength = 120;
  static const descriptionMaxLength = 1000;
  static const maxSections = 50;
  static const sectionTitleMaxLength = 120;
  static const maxTotalItems = 500;
  static const itemTextMaxLength = 500;

  /// Parses and validates a raw JSON response string.
  AiGenerationResult validate(String rawResponse) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawResponse);
    } on FormatException catch (e) {
      return _invalid('Response was not valid JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      return _invalid('Response must be a JSON object.');
    }
    return validateMap(decoded);
  }

  /// Validates an already-decoded JSON object against the contract.
  AiGenerationResult validateMap(Map<String, dynamic> map) {
    final rawTitle = map['title'];
    if (rawTitle is! String) {
      return _invalid('"title" is required and must be a string.');
    }
    final title = rawTitle.trim();
    if (title.isEmpty) {
      return _invalid('"title" must not be blank.');
    }
    if (title.length > titleMaxLength) {
      return _invalid('"title" exceeds $titleMaxLength characters.');
    }

    String? description;
    final rawDescription = map['description'];
    if (rawDescription != null) {
      if (rawDescription is! String) {
        return _invalid('"description" must be a string or null.');
      }
      if (rawDescription.length > descriptionMaxLength) {
        return _invalid(
          '"description" exceeds $descriptionMaxLength characters.',
        );
      }
      final trimmed = rawDescription.trim();
      description = trimmed.isEmpty ? null : trimmed;
    }

    final rawSections = map['sections'];
    if (rawSections is! List) {
      return _invalid('"sections" is required and must be an array.');
    }
    if (rawSections.isEmpty) {
      return _invalid('At least one section is required.');
    }
    if (rawSections.length > maxSections) {
      return _invalid('Too many sections (max $maxSections).');
    }

    final sections = <GeneratedSection>[];
    var totalItems = 0;

    for (final rawSection in rawSections) {
      if (rawSection is! Map<String, dynamic>) {
        return _invalid('Each section must be a JSON object.');
      }

      String? sectionTitle;
      final rawSectionTitle = rawSection['title'];
      if (rawSectionTitle != null) {
        if (rawSectionTitle is! String) {
          return _invalid('A section "title" must be a string or null.');
        }
        if (rawSectionTitle.length > sectionTitleMaxLength) {
          return _invalid(
            'A section title exceeds $sectionTitleMaxLength characters.',
          );
        }
        final trimmed = rawSectionTitle.trim();
        sectionTitle = trimmed.isEmpty ? null : trimmed;
      }

      final rawItems = rawSection['items'];
      if (rawItems is! List) {
        return _invalid('Each section requires an "items" array.');
      }
      if (rawItems.isEmpty) {
        return _invalid('Each section must contain at least one item.');
      }

      final items = <GeneratedItem>[];
      for (final rawItem in rawItems) {
        if (rawItem is! Map<String, dynamic>) {
          return _invalid('Each item must be a JSON object.');
        }
        final rawText = rawItem['text'];
        if (rawText is! String) {
          return _invalid('Each item requires "text" as a string.');
        }
        final text = rawText.trim();
        if (text.isEmpty) {
          return _invalid('Item text must not be blank.');
        }
        if (text.length > itemTextMaxLength) {
          return _invalid('Item text exceeds $itemTextMaxLength characters.');
        }
        items.add(GeneratedItem(text: text));
      }

      totalItems += items.length;
      if (totalItems > maxTotalItems) {
        return _invalid(
          'Too many items across all sections (max '
          '$maxTotalItems).',
        );
      }

      sections.add(GeneratedSection(title: sectionTitle, items: items));
    }

    return AiGenerationSuccess(
      GeneratedList(title: title, description: description, sections: sections),
    );
  }

  AiGenerationError _invalid(String message) => AiGenerationError(
    AiGenerationFailure(AiGenerationFailureType.invalidResponse, message),
  );
}
