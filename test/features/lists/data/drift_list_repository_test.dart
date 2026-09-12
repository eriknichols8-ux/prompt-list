import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';

void main() {
  late AppDatabase database;
  late int nextId;
  late DriftListRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    nextId = 0;
    repository = DriftListRepository(
      database,
      idGenerator: () => 'id-${nextId++}',
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
}
