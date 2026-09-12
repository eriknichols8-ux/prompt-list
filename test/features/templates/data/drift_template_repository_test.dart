import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

void main() {
  late AppDatabase database;
  late int nextId;
  late DriftTemplateRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    nextId = 0;
    repository = DriftTemplateRepository(
      database,
      idGenerator: () => 'id-${nextId++}',
    );
  });

  tearDown(() => database.close());

  group('createTemplate', () {
    test('persists a trimmed name and description', () async {
      final template = await repository.createTemplate(
        name: '  Packing  ',
        description: '  For weekend trips  ',
      );

      expect(template.name, 'Packing');
      expect(template.description, 'For weekend trips');
      expect(template.isBuiltIn, isFalse);
    });

    test('stores a blank description as null', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        description: '   ',
      );

      expect(template.description, isNull);
    });

    test('rejects a blank name and persists nothing', () async {
      await expectLater(
        repository.createTemplate(name: '   '),
        throwsA(isA<TemplateValidationException>()),
      );

      expect(await database.select(database.templates).get(), isEmpty);
    });

    test('persists sections and items in order', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        sections: const [
          TemplateSectionInput(title: 'Clothing', items: ['Shirts', 'Pants']),
          TemplateSectionInput(items: ['Charger']),
        ],
      );

      final withSections = await repository.getTemplate(template.id);

      expect(withSections!.sections, hasLength(2));
      expect(withSections.sections[0].section.title, 'Clothing');
      expect(withSections.sections[0].items.map((i) => i.content).toList(), [
        'Shirts',
        'Pants',
      ]);
      expect(withSections.sections[1].section.title, isNull);
      expect(withSections.sections[1].items.map((i) => i.content).toList(), [
        'Charger',
      ]);
    });

    test('can mark a template as built-in', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        isBuiltIn: true,
      );

      expect(template.isBuiltIn, isTrue);
    });
  });

  group('getTemplate / watchTemplate', () {
    test('returns null when the template does not exist', () async {
      expect(await repository.getTemplate('missing'), isNull);
    });

    test('a template with no sections has an empty sections list', () async {
      final template = await repository.createTemplate(name: 'Empty');

      final withSections = await repository.getTemplate(template.id);

      expect(withSections!.sections, isEmpty);
    });

    test('watchTemplate reacts to a rename', () async {
      final template = await repository.createTemplate(name: 'Packing');
      final emissions = <String?>[];
      final subscription = repository.watchTemplate(template.id).listen((t) {
        emissions.add(t?.template.name);
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, 'Packing');

      await repository.renameTemplate(templateId: template.id, name: 'Trip');
      await pumpEventQueue();
      expect(emissions.last, 'Trip');
    });
  });

  group('watchTemplates', () {
    test('orders built-ins first, then alphabetically', () async {
      await repository.createTemplate(name: 'Zebra');
      await repository.createTemplate(name: 'Apple');
      await repository.createTemplate(name: 'Built-in one', isBuiltIn: true);

      final templates = await repository.watchTemplates().first;

      expect(templates.map((t) => t.name).toList(), [
        'Built-in one',
        'Apple',
        'Zebra',
      ]);
    });
  });

  group('renameTemplate', () {
    test('updates the name', () async {
      final template = await repository.createTemplate(name: 'Packing');

      await repository.renameTemplate(templateId: template.id, name: 'Trip');

      final reloaded = await repository.getTemplate(template.id);
      expect(reloaded!.template.name, 'Trip');
    });

    test('rejects a blank name', () async {
      final template = await repository.createTemplate(name: 'Packing');

      await expectLater(
        repository.renameTemplate(templateId: template.id, name: '  '),
        throwsA(isA<TemplateValidationException>()),
      );
    });

    test('refuses to rename a built-in template', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        isBuiltIn: true,
      );

      await expectLater(
        repository.renameTemplate(templateId: template.id, name: 'Trip'),
        throwsA(isA<TemplateValidationException>()),
      );

      final reloaded = await repository.getTemplate(template.id);
      expect(reloaded!.template.name, 'Packing');
    });
  });

  group('deleteTemplate', () {
    test('removes the template and cascades sections/items', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        sections: const [
          TemplateSectionInput(title: 'Clothing', items: ['Shirts']),
        ],
      );

      await repository.deleteTemplate(template.id);

      expect(await repository.getTemplate(template.id), isNull);
      expect(await database.select(database.templateSections).get(), isEmpty);
      expect(await database.select(database.templateItems).get(), isEmpty);
    });

    test('refuses to delete a built-in template', () async {
      final template = await repository.createTemplate(
        name: 'Packing',
        isBuiltIn: true,
      );

      await expectLater(
        repository.deleteTemplate(template.id),
        throwsA(isA<TemplateValidationException>()),
      );

      expect(await repository.getTemplate(template.id), isNotNull);
    });
  });
}
