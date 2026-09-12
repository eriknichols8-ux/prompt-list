import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

void main() {
  late AppDatabase database;
  late int nextId;
  late DriftListRepository repository;
  late DriftTemplateRepository templateRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    nextId = 0;
    repository = DriftListRepository(
      database,
      idGenerator: () => 'id-${nextId++}',
    );
    templateRepository = DriftTemplateRepository(
      database,
      idGenerator: () => 'template-id-${nextId++}',
    );
  });

  tearDown(() => database.close());

  group('createList', () {
    test('persists a trimmed title and a default section', () async {
      final list = await repository.createList(title: '  Groceries  ');

      expect(list.title, 'Groceries');
      expect(list.description, isNull);

      final sections = await database.select(database.sections).get();
      expect(sections, hasLength(1));
      expect(sections.single.listId, list.id);
    });

    test('stores a trimmed description, or null when blank', () async {
      final withDescription = await repository.createList(
        title: 'Trip',
        description: '  Four days in Breckenridge  ',
      );
      expect(withDescription.description, 'Four days in Breckenridge');

      final withoutDescription = await repository.createList(
        title: 'Chores',
        description: '   ',
      );
      expect(withoutDescription.description, isNull);
    });

    test('rejects a blank title and persists nothing', () async {
      await expectLater(
        repository.createList(title: '   '),
        throwsA(isA<ListValidationException>()),
      );

      expect(await database.select(database.lists).get(), isEmpty);
      expect(await database.select(database.sections).get(), isEmpty);
    });
  });

  group('createListFromTemplate', () {
    test('copies title, description, sections, and items', () async {
      await templateRepository.createTemplate(
        name: 'Packing',
        description: 'For weekend trips',
        sections: const [
          TemplateSectionInput(title: 'Clothing', items: ['Shirts', 'Pants']),
          TemplateSectionInput(items: ['Charger']),
        ],
      );
      final template = (await templateRepository.watchTemplates().first).single;
      final withSections = await templateRepository.getTemplate(template.id);

      final list = await repository.createListFromTemplate(withSections!);

      expect(list.title, 'Packing');
      expect(list.description, 'For weekend trips');

      final sections = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).get();
      expect(sections, hasLength(2));

      final allItems = await database.select(database.listItems).get();
      expect(allItems.map((i) => i.content).toSet(), {
        'Shirts',
        'Pants',
        'Charger',
      });
    });

    test('copied items always start unchecked', () async {
      await templateRepository.createTemplate(
        name: 'Packing',
        sections: const [
          TemplateSectionInput(items: ['Shirts']),
        ],
      );
      final template = (await templateRepository.watchTemplates().first).single;
      final withSections = await templateRepository.getTemplate(template.id);

      final list = await repository.createListFromTemplate(withSections!);

      final items = await database.select(database.listItems).get();
      expect(items.single.completed, isFalse);
      expect(items.single.completedAt, isNull);
      expect(list.id, isNotEmpty);
    });

    test('a template with no sections still yields a usable list', () async {
      await templateRepository.createTemplate(name: 'Empty');
      final template = (await templateRepository.watchTemplates().first).single;
      final withSections = await templateRepository.getTemplate(template.id);

      final list = await repository.createListFromTemplate(withSections!);

      final sections = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).get();
      expect(sections, hasLength(1));
    });

    test('editing the new list never mutates the source template', () async {
      await templateRepository.createTemplate(
        name: 'Packing',
        sections: const [
          TemplateSectionInput(items: ['Shirts']),
        ],
      );
      final template = (await templateRepository.watchTemplates().first).single;
      final withSections = await templateRepository.getTemplate(template.id);

      final list = await repository.createListFromTemplate(withSections!);
      final newItem = (await database.select(database.listItems).get()).single;

      // Edit the new list's copy: complete it and change its text.
      await (database.update(
        database.listItems,
      )..where((tbl) => tbl.id.equals(newItem.id))).write(
        ListItemsCompanion(
          content: const Value('Shirts (packed)'),
          completed: const Value(true),
        ),
      );
      await repository.renameList(id: list.id, title: 'Trip');

      final reloadedTemplate = await templateRepository.getTemplate(
        template.id,
      );
      expect(reloadedTemplate!.template.name, 'Packing');
      expect(reloadedTemplate.sections.single.items.single.content, 'Shirts');
    });
  });

  group('getList', () {
    test('returns null when the list does not exist', () async {
      expect(await repository.getList('missing'), isNull);
    });

    test('returns the persisted list', () async {
      final created = await repository.createList(title: 'Groceries');

      final fetched = await repository.getList(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.title, 'Groceries');
    });
  });

  group('watchList', () {
    test('emits null when the list does not exist', () async {
      expect(await repository.watchList('missing').first, isNull);
    });

    test('emits updates as the list is renamed', () async {
      final created = await repository.createList(title: 'Groceries');
      final emissions = <String?>[];
      final subscription = repository.watchList(created.id).listen((list) {
        emissions.add(list?.title);
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, 'Groceries');

      await repository.renameList(id: created.id, title: 'Weekly Shop');
      await pumpEventQueue();
      expect(emissions.last, 'Weekly Shop');
    });
  });

  group('renameList', () {
    test('updates the title and updatedAt', () async {
      final created = await repository.createList(title: 'Groceries');
      final before = created.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.renameList(id: created.id, title: '  Weekly Shop  ');

      final renamed = await repository.getList(created.id);
      expect(renamed!.title, 'Weekly Shop');
      expect(renamed.updatedAt.isAfter(before), isTrue);
    });

    test('rejects a blank title and leaves the list unchanged', () async {
      final created = await repository.createList(title: 'Groceries');

      await expectLater(
        repository.renameList(id: created.id, title: '  '),
        throwsA(isA<ListValidationException>()),
      );

      final unchanged = await repository.getList(created.id);
      expect(unchanged!.title, 'Groceries');
    });
  });

  group('deleteList', () {
    test('removes the list and cascades to sections and items', () async {
      final created = await repository.createList(title: 'Groceries');
      final section = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(created.id))).getSingle();
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-0',
              sectionId: section.id,
              content: 'Milk',
              sortOrder: 1000,
              createdAt: DateTime.now(),
            ),
          );

      await repository.deleteList(created.id);

      expect(await repository.getList(created.id), isNull);
      expect(await database.select(database.sections).get(), isEmpty);
      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('archiveList / unarchiveList', () {
    test(
      'archiving hides a list from getList results still returning it',
      () async {
        final created = await repository.createList(title: 'Groceries');

        await repository.archiveList(created.id);

        final archived = await repository.getList(created.id);
        expect(
          archived,
          isNotNull,
          reason: 'getList is not filtered by archivedAt',
        );
        expect(archived!.archivedAt, isNotNull);

        final lists = await database.select(database.lists).get();
        expect(lists.single.archivedAt, isNotNull);
      },
    );

    test('unarchiving restores a list', () async {
      final created = await repository.createList(title: 'Groceries');
      await repository.archiveList(created.id);

      await repository.unarchiveList(created.id);

      final restored = await repository.getList(created.id);
      expect(restored!.archivedAt, isNull);
    });

    test('does not delete sections or items', () async {
      final created = await repository.createList(title: 'Groceries');
      final section = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(created.id))).getSingle();
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-0',
              sectionId: section.id,
              content: 'Milk',
              sortOrder: 1000,
              createdAt: DateTime.now(),
            ),
          );

      await repository.archiveList(created.id);

      expect(await database.select(database.sections).get(), hasLength(1));
      expect(await database.select(database.listItems).get(), hasLength(1));
    });

    test(
      'watchLists excludes an archived list and includes it again on undo',
      () async {
        final created = await repository.createList(title: 'Groceries');
        final emissions = <int>[];
        final subscription = repository.watchLists().listen((lists) {
          emissions.add(lists.length);
        });
        addTearDown(subscription.cancel);
        await pumpEventQueue();
        expect(emissions.last, 1);

        await repository.archiveList(created.id);
        await pumpEventQueue();
        expect(emissions.last, 0);

        await repository.unarchiveList(created.id);
        await pumpEventQueue();
        expect(emissions.last, 1);
      },
    );
  });

  group('watchLists', () {
    test(
      'emits updates as lists are created and excludes archived ones',
      () async {
        final emissions = <int>[];
        final subscription = repository.watchLists().listen((lists) {
          emissions.add(lists.length);
        });
        addTearDown(subscription.cancel);

        await pumpEventQueue();
        expect(emissions, [0]);

        final first = await repository.createList(title: 'Groceries');
        await pumpEventQueue();
        expect(emissions.last, 1);

        await repository.createList(title: 'Packing');
        await pumpEventQueue();
        expect(emissions.last, 2);

        await (database.update(database.lists)
              ..where((tbl) => tbl.id.equals(first.id)))
            .write(ListsCompanion(archivedAt: Value(DateTime.now())));
        await pumpEventQueue();
        expect(emissions.last, 1);
      },
    );
  });

  group('watchListSummaries', () {
    test('reports item totals and reacts to completion toggles', () async {
      final list = await repository.createList(title: 'Groceries');
      final section = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).getSingle();
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-0',
              sectionId: section.id,
              content: 'Milk',
              sortOrder: 1000,
              createdAt: DateTime.now(),
            ),
          );
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              sectionId: section.id,
              content: 'Eggs',
              sortOrder: 2000,
              createdAt: DateTime.now(),
            ),
          );

      final emissions = <(int, int)>[];
      final subscription = repository.watchListSummaries().listen((summaries) {
        final summary = summaries.single;
        emissions.add((summary.totalItems, summary.completedItems));
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, (2, 0));

      await (database.update(database.listItems)
            ..where((tbl) => tbl.id.equals('item-0')))
          .write(const ListItemsCompanion(completed: Value(true)));
      await pumpEventQueue();
      expect(emissions.last, (2, 1));

      await (database.update(database.listItems)
            ..where((tbl) => tbl.id.equals('item-0')))
          .write(const ListItemsCompanion(completed: Value(false)));
      await pumpEventQueue();
      expect(emissions.last, (2, 0));
    });
  });
}
