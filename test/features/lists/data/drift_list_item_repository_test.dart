import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';

void main() {
  late AppDatabase database;
  late String listId;
  late DriftListItemRepository repository;

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
    await database
        .into(database.sections)
        .insert(
          SectionsCompanion.insert(
            id: 'section-1',
            listId: listId,
            sortOrder: 1000,
          ),
        );

    var nextId = 0;
    repository = DriftListItemRepository(
      database,
      idGenerator: () => 'item-${nextId++}',
    );
  });

  tearDown(() => database.close());

  group('addItem', () {
    test(
      'persists a trimmed, incomplete item with increasing sort order',
      () async {
        final first = await repository.addItem(
          listId: listId,
          text: '  Milk  ',
        );
        final second = await repository.addItem(listId: listId, text: 'Eggs');

        expect(first.content, 'Milk');
        expect(first.completed, isFalse);
        expect(second.sortOrder, greaterThan(first.sortOrder));
      },
    );

    test('rejects blank text and persists nothing', () async {
      await expectLater(
        repository.addItem(listId: listId, text: '   '),
        throwsA(isA<ListItemValidationException>()),
      );

      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('editItemText', () {
    test('updates the text of an existing item', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');

      await repository.editItemText(itemId: item.id, text: '  Oat milk  ');

      final updated = await (database.select(
        database.listItems,
      )..where((tbl) => tbl.id.equals(item.id))).getSingle();
      expect(updated.content, 'Oat milk');
    });

    test('rejects blank text and leaves the item unchanged', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');

      await expectLater(
        repository.editItemText(itemId: item.id, text: '  '),
        throwsA(isA<ListItemValidationException>()),
      );

      final unchanged = await (database.select(
        database.listItems,
      )..where((tbl) => tbl.id.equals(item.id))).getSingle();
      expect(unchanged.content, 'Milk');
    });
  });

  group('deleteItem', () {
    test('removes the item', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');

      await repository.deleteItem(item.id);

      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('watchItems', () {
    test('emits items for the list in sort order', () async {
      final emissions = <List<String>>[];
      final subscription = repository.watchItems(listId).listen((items) {
        emissions.add(items.map((item) => item.content).toList());
      });
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await repository.addItem(listId: listId, text: 'Milk');
      await pumpEventQueue();
      expect(emissions.last, ['Milk']);

      await repository.addItem(listId: listId, text: 'Eggs');
      await pumpEventQueue();
      expect(emissions.last, ['Milk', 'Eggs']);
    });
  });
}
