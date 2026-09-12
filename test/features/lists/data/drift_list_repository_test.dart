import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
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

  group('createListFromGeneratedList', () {
    const sample = GeneratedList(
      title: 'Camping trip',
      description: 'Pack for a weekend camping trip.',
      sections: [
        GeneratedSection(
          title: 'Shelter',
          items: [
            GeneratedItem(text: 'Tent'),
            GeneratedItem(text: 'Sleeping bag'),
          ],
        ),
        GeneratedSection(title: null, items: [GeneratedItem(text: 'Lantern')]),
      ],
    );

    test('copies title, description, sections, and items', () async {
      final list = await repository.createListFromGeneratedList(sample);

      expect(list.title, 'Camping trip');
      expect(list.description, 'Pack for a weekend camping trip.');

      final sections = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).get();
      expect(sections, hasLength(2));

      final allItems = await database.select(database.listItems).get();
      expect(allItems.map((i) => i.content).toSet(), {
        'Tent',
        'Sleeping bag',
        'Lantern',
      });
    });

    test('items always start unchecked', () async {
      final list = await repository.createListFromGeneratedList(sample);

      final items = await database.select(database.listItems).get();
      expect(items, isNotEmpty);
      expect(items.every((i) => !i.completed), isTrue);
      expect(items.every((i) => i.completedAt == null), isTrue);
      expect(list.id, isNotEmpty);
    });

    test(
      'a generated list with no sections still yields a usable list',
      () async {
        const empty = GeneratedList(title: 'Empty', sections: []);

        final list = await repository.createListFromGeneratedList(empty);

        final sections = await (database.select(
          database.sections,
        )..where((tbl) => tbl.listId.equals(list.id))).get();
        expect(sections, hasLength(1));
      },
    );

    test('a mid-transaction failure leaves no partial list behind', () async {
      // A generator that always returns the same id forces a primary
      // key collision on the second section insert, so the whole
      // transaction must roll back rather than leaving the list and
      // first section committed.
      final poisoned = DriftListRepository(database, idGenerator: () => 'x');
      const twoSections = GeneratedList(
        title: 'Doomed list',
        sections: [
          GeneratedSection(items: [GeneratedItem(text: 'A')]),
          GeneratedSection(items: [GeneratedItem(text: 'B')]),
        ],
      );

      await expectLater(
        poisoned.createListFromGeneratedList(twoSections),
        throwsA(anything),
      );

      expect(await database.select(database.lists).get(), isEmpty);
      expect(await database.select(database.sections).get(), isEmpty);
      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('applyGeneratedListModification', () {
    Future<ListRecord> createGroceriesWithMilkAndEggs() async {
      final list = await repository.createList(title: 'Groceries');
      final section = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).getSingle();
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'milk',
              sectionId: section.id,
              content: 'Milk',
              sortOrder: 1000,
              createdAt: DateTime.now(),
              completed: const Value(true),
              completedAt: Value(DateTime.now()),
            ),
          );
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'eggs',
              sectionId: section.id,
              content: 'Eggs',
              sortOrder: 2000,
              createdAt: DateTime.now(),
            ),
          );
      return list;
    }

    test('replaces title, description, sections, and items', () async {
      final list = await createGroceriesWithMilkAndEggs();

      final updated = await repository.applyGeneratedListModification(
        listId: list.id,
        modified: const GeneratedList(
          title: 'Weekly groceries',
          description: 'Updated by AI',
          sections: [
            GeneratedSection(
              title: 'Dairy',
              items: [
                GeneratedItem(text: 'Milk'),
                GeneratedItem(text: 'Cheese'),
              ],
            ),
          ],
        ),
      );

      expect(updated.title, 'Weekly groceries');
      expect(updated.description, 'Updated by AI');

      final sections = await (database.select(
        database.sections,
      )..where((tbl) => tbl.listId.equals(list.id))).get();
      expect(sections, hasLength(1));
      expect(sections.single.title, 'Dairy');

      final items = await database.select(database.listItems).get();
      expect(items.map((i) => i.content).toSet(), {'Milk', 'Cheese'});
    });

    test('preserves completion only for an exact-text match, and never for '
        'new items', () async {
      final list = await createGroceriesWithMilkAndEggs();

      await repository.applyGeneratedListModification(
        listId: list.id,
        modified: const GeneratedList(
          title: 'Groceries',
          sections: [
            GeneratedSection(
              items: [
                GeneratedItem(text: 'Milk'), // unchanged -> stays checked
                GeneratedItem(text: 'Eggs'), // unchanged, already unchecked
                GeneratedItem(text: 'Bread'), // new -> starts unchecked
              ],
            ),
          ],
        ),
      );

      final items = await database.select(database.listItems).get();
      final byContent = {for (final i in items) i.content: i};
      expect(byContent['Milk']!.completed, isTrue);
      expect(byContent['Eggs']!.completed, isFalse);
      expect(byContent['Bread']!.completed, isFalse);
    });

    test('a reworded item is treated as new and starts unchecked', () async {
      final list = await createGroceriesWithMilkAndEggs();

      await repository.applyGeneratedListModification(
        listId: list.id,
        modified: const GeneratedList(
          title: 'Groceries',
          sections: [
            GeneratedSection(items: [GeneratedItem(text: 'Whole milk')]),
          ],
        ),
      );

      final item = (await database.select(database.listItems).get()).single;
      expect(item.content, 'Whole milk');
      expect(item.completed, isFalse);
    });

    test(
      'duplicate matching text only preserves completion for one item',
      () async {
        final list = await repository.createList(title: 'Groceries');
        final section = await (database.select(
          database.sections,
        )..where((tbl) => tbl.listId.equals(list.id))).getSingle();
        await database
            .into(database.listItems)
            .insert(
              ListItemsCompanion.insert(
                id: 'milk-completed',
                sectionId: section.id,
                content: 'Milk',
                sortOrder: 1000,
                createdAt: DateTime.now(),
                completed: const Value(true),
              ),
            );

        await repository.applyGeneratedListModification(
          listId: list.id,
          modified: const GeneratedList(
            title: 'Groceries',
            sections: [
              GeneratedSection(
                items: [
                  GeneratedItem(text: 'Milk'),
                  GeneratedItem(text: 'Milk'),
                ],
              ),
            ],
          ),
        );

        final items = await database.select(database.listItems).get();
        expect(items, hasLength(2));
        expect(items.where((i) => i.completed), hasLength(1));
      },
    );

    test(
      'a modification with no sections still yields a usable list',
      () async {
        final list = await createGroceriesWithMilkAndEggs();

        await repository.applyGeneratedListModification(
          listId: list.id,
          modified: const GeneratedList(title: 'Empty now', sections: []),
        );

        final sections = await (database.select(
          database.sections,
        )..where((tbl) => tbl.listId.equals(list.id))).get();
        expect(sections, hasLength(1));
        expect(await database.select(database.listItems).get(), isEmpty);
      },
    );

    test(
      'a mid-transaction failure leaves the original list completely intact',
      () async {
        final poisoned = DriftListRepository(database, idGenerator: () => 'x');
        final list = await poisoned.createList(title: 'Groceries');
        final section = await (database.select(
          database.sections,
        )..where((tbl) => tbl.listId.equals(list.id))).getSingle();
        await database
            .into(database.listItems)
            .insert(
              ListItemsCompanion.insert(
                id: 'milk',
                sectionId: section.id,
                content: 'Milk',
                sortOrder: 1000,
                createdAt: DateTime.now(),
                completed: const Value(true),
              ),
            );

        await expectLater(
          poisoned.applyGeneratedListModification(
            listId: list.id,
            modified: const GeneratedList(
              title: 'Doomed update',
              sections: [
                GeneratedSection(items: [GeneratedItem(text: 'A')]),
                GeneratedSection(items: [GeneratedItem(text: 'B')]),
              ],
            ),
          ),
          throwsA(anything),
        );

        final reloaded = await repository.getList(list.id);
        expect(reloaded!.title, 'Groceries');
        final items = await database.select(database.listItems).get();
        expect(items.single.content, 'Milk');
        expect(items.single.completed, isTrue);
      },
    );
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
