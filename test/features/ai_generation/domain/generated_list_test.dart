import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';

void main() {
  group('GeneratedList value equality', () {
    test('equal when title, description, and sections match', () {
      const a = GeneratedList(
        title: 'Groceries',
        description: 'Weekly run',
        sections: [
          GeneratedSection(
            title: 'Produce',
            items: [GeneratedItem(text: 'Apples')],
          ),
        ],
      );
      const b = GeneratedList(
        title: 'Groceries',
        description: 'Weekly run',
        sections: [
          GeneratedSection(
            title: 'Produce',
            items: [GeneratedItem(text: 'Apples')],
          ),
        ],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when an item differs', () {
      const a = GeneratedList(
        title: 'Groceries',
        sections: [
          GeneratedSection(items: [GeneratedItem(text: 'Apples')]),
        ],
      );
      const b = GeneratedList(
        title: 'Groceries',
        sections: [
          GeneratedSection(items: [GeneratedItem(text: 'Bananas')]),
        ],
      );

      expect(a, isNot(equals(b)));
    });

    test('supports a null description and null section title', () {
      const list = GeneratedList(
        title: 'Untitled section list',
        sections: [
          GeneratedSection(items: [GeneratedItem(text: 'Item')]),
        ],
      );

      expect(list.description, isNull);
      expect(list.sections.single.title, isNull);
    });
  });

  group('toJson', () {
    test('encodes the canonical AI_CONTRACT.md field names', () {
      const list = GeneratedList(
        title: 'Groceries',
        description: 'Weekly run',
        sections: [
          GeneratedSection(
            title: 'Produce',
            items: [
              GeneratedItem(text: 'Apples'),
              GeneratedItem(text: 'Pears'),
            ],
          ),
          GeneratedSection(title: null, items: [GeneratedItem(text: 'Bread')]),
        ],
      );

      expect(list.toJson(), {
        'title': 'Groceries',
        'description': 'Weekly run',
        'sections': [
          {
            'title': 'Produce',
            'items': [
              {'text': 'Apples'},
              {'text': 'Pears'},
            ],
          },
          {
            'title': null,
            'items': [
              {'text': 'Bread'},
            ],
          },
        ],
      });
    });

    test('round-trips through jsonEncode without throwing', () {
      const list = GeneratedList(
        title: 'Groceries',
        sections: [
          GeneratedSection(items: [GeneratedItem(text: 'Milk')]),
        ],
      );

      expect(() => jsonEncode(list.toJson()), returnsNormally);
    });
  });
}
