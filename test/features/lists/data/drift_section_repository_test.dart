import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_section_repository.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';

void main() {
  late AppDatabase database;
  late String listId;
  late DriftSectionRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    listId = 'list-1';
    final now = DateTime.now();
    await database
        .into(database.lists)
        .insert(
          ListsCompanion.insert(
            id: listId,
            title: 'Groceries',
            createdAt: now,
            updatedAt: now,
          ),
        );

    var nextId = 0;
    repository = DriftSectionRepository(
      database,
      idGenerator: () => 'section-${nextId++}',
    );
  });

  tearDown(() => database.close());

  Future<List<String?>> orderedTitles() async {
    final sections = await repository.watchSections(listId).first;
    return sections.map((section) => section.title).toList();
  }

  group('createSection', () {
    test('creates a titled section after existing ones', () async {
      final first = await repository.createSection(
        listId: listId,
        title: 'Produce',
      );
      final second = await repository.createSection(
        listId: listId,
        title: '  Dairy  ',
      );

      expect(first.title, 'Produce');
      expect(second.title, 'Dairy');
      expect(second.sortOrder, greaterThan(first.sortOrder));
    });

    test('stores a blank or omitted title as null', () async {
      final untitled = await repository.createSection(listId: listId);
      final blank = await repository.createSection(
        listId: listId,
        title: '   ',
      );

      expect(untitled.title, isNull);
      expect(blank.title, isNull);
    });
  });

  group('renameSection', () {
    test('updates the title', () async {
      final section = await repository.createSection(
        listId: listId,
        title: 'Produce',
      );

      await repository.renameSection(sectionId: section.id, title: 'Fruit');

      expect(await orderedTitles(), ['Fruit']);
    });

    test('a blank or null title clears it back to untitled', () async {
      final section = await repository.createSection(
        listId: listId,
        title: 'Produce',
      );

      await repository.renameSection(sectionId: section.id, title: '   ');

      expect(await orderedTitles(), [null]);
    });
  });

  group('deleteSection', () {
    test('removes a non-last section and cascades its items', () async {
      final first = await repository.createSection(
        listId: listId,
        title: 'Produce',
      );
      await repository.createSection(listId: listId, title: 'Dairy');
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              sectionId: first.id,
              content: 'Apples',
              sortOrder: 1000,
              createdAt: DateTime.now(),
            ),
          );

      await repository.deleteSection(first.id);

      expect(await orderedTitles(), ['Dairy']);
      expect(await database.select(database.listItems).get(), isEmpty);
    });

    test('refuses to delete the only remaining section', () async {
      final only = await repository.createSection(
        listId: listId,
        title: 'Produce',
      );

      await expectLater(
        repository.deleteSection(only.id),
        throwsA(isA<SectionValidationException>()),
      );

      expect(await orderedTitles(), ['Produce']);
    });
  });

  group('reorderSection', () {
    test('move first to last', () async {
      await repository.createSection(listId: listId, title: 'A');
      await repository.createSection(listId: listId, title: 'B');
      await repository.createSection(listId: listId, title: 'C');

      await repository.reorderSection(listId: listId, oldIndex: 0, newIndex: 2);

      expect(await orderedTitles(), ['B', 'C', 'A']);
    });

    test('move last to first', () async {
      await repository.createSection(listId: listId, title: 'A');
      await repository.createSection(listId: listId, title: 'B');
      await repository.createSection(listId: listId, title: 'C');

      await repository.reorderSection(listId: listId, oldIndex: 2, newIndex: 0);

      expect(await orderedTitles(), ['C', 'A', 'B']);
    });

    test('repeated reorders do not corrupt ordering', () async {
      await repository.createSection(listId: listId, title: 'A');
      await repository.createSection(listId: listId, title: 'B');
      await repository.createSection(listId: listId, title: 'C');

      await repository.reorderSection(listId: listId, oldIndex: 0, newIndex: 2);
      await repository.reorderSection(listId: listId, oldIndex: 2, newIndex: 0);
      await repository.reorderSection(listId: listId, oldIndex: 1, newIndex: 0);

      expect(await orderedTitles(), ['B', 'A', 'C']);

      final sortOrders = (await repository.watchSections(listId).first)
          .map((section) => section.sortOrder)
          .toList();
      final ascending = List<int>.from(sortOrders)..sort();
      expect(sortOrders, ascending);
      expect(sortOrders.toSet(), hasLength(3));
    });

    test('reordering a single section is a no-op', () async {
      await repository.createSection(listId: listId, title: 'A');

      await repository.reorderSection(listId: listId, oldIndex: 0, newIndex: 0);

      expect(await orderedTitles(), ['A']);
    });

    test('new order persists across a fresh repository instance', () async {
      await repository.createSection(listId: listId, title: 'A');
      await repository.createSection(listId: listId, title: 'B');

      await repository.reorderSection(listId: listId, oldIndex: 0, newIndex: 1);

      final reloaded = await DriftSectionRepository(database)
          .watchSections(listId)
          .first;
      expect(reloaded.map((s) => s.title).toList(), ['B', 'A']);
    });
  });

  group('watchSections', () {
    test('emits updates as sections are created and reordered', () async {
      final emissions = <List<String?>>[];
      final subscription = repository.watchSections(listId).listen((sections) {
        emissions.add(sections.map((s) => s.title).toList());
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await repository.createSection(listId: listId, title: 'Produce');
      await pumpEventQueue();
      expect(emissions.last, ['Produce']);
    });
  });

  group('getSections', () {
    test(
      'reads the current sections in the same order as watchSections',
      () async {
        await repository.createSection(listId: listId, title: 'Produce');
        await repository.createSection(listId: listId, title: 'Dairy');

        final sections = await repository.getSections(listId);

        expect(sections.map((s) => s.title).toList(), ['Produce', 'Dairy']);
      },
    );
  });
}
