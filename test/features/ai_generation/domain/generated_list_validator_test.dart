import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list_validator.dart';

void main() {
  final validator = GeneratedListValidator();

  AiGenerationSuccess expectSuccess(String json) {
    final result = validator.validate(json);
    expect(result, isA<AiGenerationSuccess>());
    return result as AiGenerationSuccess;
  }

  AiGenerationError expectInvalid(String json) {
    final result = validator.validate(json);
    expect(result, isA<AiGenerationError>());
    final error = result as AiGenerationError;
    expect(error.failure.type, AiGenerationFailureType.invalidResponse);
    return error;
  }

  group('valid payloads', () {
    test('simple single-section list', () {
      final result = expectSuccess(
        jsonEncode({
          'title': 'Weekend Errands',
          'description': null,
          'sections': [
            {
              'title': null,
              'items': [
                {'text': 'Post office'},
                {'text': 'Pharmacy'},
              ],
            },
          ],
        }),
      );

      final list = result.list;
      expect(list.title, 'Weekend Errands');
      expect(list.description, isNull);
      expect(list.sections, hasLength(1));
      expect(list.sections.single.title, isNull);
      expect(list.sections.single.items.map((i) => i.text), [
        'Post office',
        'Pharmacy',
      ]);
    });

    test('sectioned list with titled sections and a description', () {
      final result = expectSuccess(
        jsonEncode({
          'title': 'Marvel Movies in Chronological Order',
          'description': 'Ordered by in-universe chronology.',
          'sections': [
            {
              'title': 'Phase One',
              'items': [
                {'text': 'Captain America: The First Avenger'},
                {'text': 'Iron Man'},
              ],
            },
            {
              'title': 'Phase Two',
              'items': [
                {'text': 'Captain Marvel'},
              ],
            },
          ],
        }),
      );

      final list = result.list;
      expect(list.description, 'Ordered by in-universe chronology.');
      expect(list.sections.map((s) => s.title), ['Phase One', 'Phase Two']);
      expect(list.sections[1].items.single.text, 'Captain Marvel');
    });

    test('preserves unicode text', () {
      final result = expectSuccess(
        jsonEncode({
          'title': 'Café Crawl ☕',
          'sections': [
            {
              'items': [
                {'text': '東京のカフェ'},
                {'text': 'Résumé review 📋'},
              ],
            },
          ],
        }),
      );

      expect(result.list.title, 'Café Crawl ☕');
      expect(result.list.sections.single.items.map((i) => i.text), [
        '東京のカフェ',
        'Résumé review 📋',
      ]);
    });

    test('trims whitespace and normalizes blank optional fields to null', () {
      final result = expectSuccess(
        jsonEncode({
          'title': '  Groceries  ',
          'description': '   ',
          'sections': [
            {
              'title': '   ',
              'items': [
                {'text': '  Milk  '},
              ],
            },
          ],
        }),
      );

      expect(result.list.title, 'Groceries');
      expect(result.list.description, isNull);
      expect(result.list.sections.single.title, isNull);
      expect(result.list.sections.single.items.single.text, 'Milk');
    });

    test('accepts maximum-size boundary payload', () {
      final title = 'T' * GeneratedListValidator.titleMaxLength;
      final description = 'D' * GeneratedListValidator.descriptionMaxLength;
      final sectionTitle = 'S' * GeneratedListValidator.sectionTitleMaxLength;
      final itemText = 'I' * GeneratedListValidator.itemTextMaxLength;

      // 50 sections * 10 items = 500 total items, at the documented max.
      final sections = List.generate(
        GeneratedListValidator.maxSections,
        (_) => {
          'title': sectionTitle,
          'items': List.generate(10, (_) => {'text': itemText}),
        },
      );

      final result = expectSuccess(
        jsonEncode({
          'title': title,
          'description': description,
          'sections': sections,
        }),
      );

      expect(result.list.title.length, GeneratedListValidator.titleMaxLength);
      expect(result.list.sections, hasLength(50));
      expect(
        result.list.sections.fold<int>(0, (sum, s) => sum + s.items.length),
        500,
      );
    });

    test('omits optional description entirely', () {
      final result = expectSuccess(
        jsonEncode({
          'title': 'No description field',
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );

      expect(result.list.description, isNull);
    });
  });

  group('malformed JSON', () {
    test('rejects unparseable JSON text', () {
      expectInvalid('{not valid json');
    });

    test('rejects a JSON root that is not an object', () {
      expectInvalid(jsonEncode(['title', 'sections']));
    });
  });

  group('wrong types', () {
    test('rejects a non-string title', () {
      expectInvalid(
        jsonEncode({
          'title': 42,
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects a non-string description', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'description': 42,
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects sections that are not a list', () {
      expectInvalid(jsonEncode({'title': 'List', 'sections': 'nope'}));
    });

    test('rejects a section that is not an object', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': ['not an object'],
        }),
      );
    });

    test('rejects items that are not a list', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {'items': 'nope'},
          ],
        }),
      );
    });

    test('rejects a non-string item text', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {
              'items': [
                {'text': 123},
              ],
            },
          ],
        }),
      );
    });
  });

  group('blank strings', () {
    test('rejects a blank title', () {
      expectInvalid(
        jsonEncode({
          'title': '   ',
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects blank item text', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {
              'items': [
                {'text': '   '},
              ],
            },
          ],
        }),
      );
    });
  });

  group('missing required fields', () {
    test('rejects a payload with no title', () {
      expectInvalid(
        jsonEncode({
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects a payload with no sections', () {
      expectInvalid(jsonEncode({'title': 'List'}));
    });

    test('rejects an empty sections array', () {
      expectInvalid(jsonEncode({'title': 'List', 'sections': []}));
    });

    test('rejects a section with no items', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {'items': []},
          ],
        }),
      );
    });

    test('rejects an item with no text field', () {
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {
              'items': [<String, dynamic>{}],
            },
          ],
        }),
      );
    });
  });

  group('limits exceeded', () {
    test('rejects too many sections', () {
      final sections = List.generate(
        GeneratedListValidator.maxSections + 1,
        (_) => {
          'items': [
            {'text': 'Item'},
          ],
        },
      );
      expectInvalid(jsonEncode({'title': 'List', 'sections': sections}));
    });

    test('rejects too many total items across sections', () {
      final items = List.generate(
        GeneratedListValidator.maxTotalItems + 1,
        (_) => {'text': 'Item'},
      );
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {'items': items},
          ],
        }),
      );
    });

    test('rejects an overlong title', () {
      final title = 'T' * (GeneratedListValidator.titleMaxLength + 1);
      expectInvalid(
        jsonEncode({
          'title': title,
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects an overlong description', () {
      final description =
          'D' * (GeneratedListValidator.descriptionMaxLength + 1);
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'description': description,
          'sections': [
            {
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects an overlong section title', () {
      final sectionTitle =
          'S' * (GeneratedListValidator.sectionTitleMaxLength + 1);
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {
              'title': sectionTitle,
              'items': [
                {'text': 'Item'},
              ],
            },
          ],
        }),
      );
    });

    test('rejects overlong item text', () {
      final itemText = 'I' * (GeneratedListValidator.itemTextMaxLength + 1);
      expectInvalid(
        jsonEncode({
          'title': 'List',
          'sections': [
            {
              'items': [
                {'text': itemText},
              ],
            },
          ],
        }),
      );
    });
  });
}
