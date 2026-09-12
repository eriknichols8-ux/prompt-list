import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';

void main() {
  late AppDatabase database;
  late String listId;
  late String sectionId;
  late DriftListItemRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    listId = 'list-1';
    sectionId = 'section-1';
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
            id: sectionId,
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

    test(
      'adds to the first section by sort order when several exist',
      () async {
        await database
            .into(database.sections)
            .insert(
              SectionsCompanion.insert(
                id: 'section-0',
                listId: listId,
                sortOrder: 500,
              ),
            );

        final item = await repository.addItem(listId: listId, text: 'Milk');

        expect(item.sectionId, 'section-0');
      },
    );
  });

  group('addItemToSection', () {
    test('adds a trimmed item to the given section', () async {
      final item = await repository.addItemToSection(
        sectionId: sectionId,
        text: '  Milk  ',
      );

      expect(item.sectionId, sectionId);
      expect(item.content, 'Milk');
    });

    test('rejects blank text and persists nothing', () async {
      await expectLater(
        repository.addItemToSection(sectionId: sectionId, text: '  '),
        throwsA(isA<ListItemValidationException>()),
      );

      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('moveItemToSection', () {
    test(
      'moves an item and appends it after the target section\'s items',
      () async {
        final otherSectionId = 'section-2';
        await database
            .into(database.sections)
            .insert(
              SectionsCompanion.insert(
                id: otherSectionId,
                listId: listId,
                sortOrder: 2000,
              ),
            );
        await repository.addItemToSection(
          sectionId: otherSectionId,
          text: 'Existing',
        );
        final item = await repository.addItem(listId: listId, text: 'Milk');

        await repository.moveItemToSection(
          itemId: item.id,
          targetSectionId: otherSectionId,
        );

        final sourceItems = await repository.watchItems(listId).first;
        final moved = sourceItems.singleWhere((i) => i.id == item.id);
        expect(moved.sectionId, otherSectionId);

        final targetItems = await (database.select(
          database.listItems,
        )..where((tbl) => tbl.sectionId.equals(otherSectionId))).get();
        targetItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        expect(targetItems.map((i) => i.content).toList(), [
          'Existing',
          'Milk',
        ]);
      },
    );
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

  group('setItemCompleted', () {
    test('completing an item stamps completedAt', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');
      expect(item.completedAt, isNull);

      await repository.setItemCompleted(itemId: item.id, completed: true);

      final completed = await (database.select(
        database.listItems,
      )..where((tbl) => tbl.id.equals(item.id))).getSingle();
      expect(completed.completed, isTrue);
      expect(completed.completedAt, isNotNull);
    });

    test('uncompleting an item clears completedAt', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');
      await repository.setItemCompleted(itemId: item.id, completed: true);

      await repository.setItemCompleted(itemId: item.id, completed: false);

      final uncompleted = await (database.select(
        database.listItems,
      )..where((tbl) => tbl.id.equals(item.id))).getSingle();
      expect(uncompleted.completed, isFalse);
      expect(uncompleted.completedAt, isNull);
    });
  });

  group('deleteItem', () {
    test('removes the item', () async {
      final item = await repository.addItem(listId: listId, text: 'Milk');

      await repository.deleteItem(item.id);

      expect(await database.select(database.listItems).get(), isEmpty);
    });
  });

  group('clearCompleted', () {
    test('removes only completed items', () async {
      final milk = await repository.addItem(listId: listId, text: 'Milk');
      await repository.addItem(listId: listId, text: 'Eggs');
      await repository.setItemCompleted(itemId: milk.id, completed: true);

      await repository.clearCompleted(listId);

      final remaining = await repository.watchItems(listId).first;
      expect(remaining.map((item) => item.content).toList(), ['Eggs']);
    });

    test('does nothing when no items are completed', () async {
      await repository.addItem(listId: listId, text: 'Milk');

      await repository.clearCompleted(listId);

      final remaining = await repository.watchItems(listId).first;
      expect(remaining, hasLength(1));
    });
  });

  group('reorderItem', () {
    Future<List<String>> orderedContents() async {
      final items = await repository.watchItems(listId).first;
      return items.map((item) => item.content).toList();
    }

    test('move first to last', () async {
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.addItem(listId: listId, text: 'C');

      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 0,
        newIndex: 2,
      );

      expect(await orderedContents(), ['B', 'C', 'A']);
    });

    test('move last to first', () async {
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.addItem(listId: listId, text: 'C');

      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 2,
        newIndex: 0,
      );

      expect(await orderedContents(), ['C', 'A', 'B']);
    });

    test('move middle to middle', () async {
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.addItem(listId: listId, text: 'C');
      await repository.addItem(listId: listId, text: 'D');

      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 1,
        newIndex: 2,
      );

      expect(await orderedContents(), ['A', 'C', 'B', 'D']);
    });

    test('repeated reorders do not corrupt ordering', () async {
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.addItem(listId: listId, text: 'C');

      // [A,B,C] -> move A to the end -> [B,C,A]
      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 0,
        newIndex: 2,
      );
      // [B,C,A] -> move A (index 2) to the front -> [A,B,C]
      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 2,
        newIndex: 0,
      );
      // [A,B,C] -> move B (index 1) to the front -> [B,A,C]
      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 1,
        newIndex: 0,
      );

      expect(await orderedContents(), ['B', 'A', 'C']);

      final sortOrders = (await repository.watchItems(listId).first)
          .map((item) => item.sortOrder)
          .toList();
      final ascending = List<int>.from(sortOrders)..sort();
      expect(
        sortOrders,
        ascending,
        reason: 'sort order must match display order',
      );
      expect(
        sortOrders.toSet(),
        hasLength(3),
        reason: 'no duplicate sort orders',
      );
    });

    test(
      'reordering after a deletion keeps the remaining items in order',
      () async {
        final a = await repository.addItem(listId: listId, text: 'A');
        await repository.addItem(listId: listId, text: 'B');
        await repository.addItem(listId: listId, text: 'C');
        await repository.deleteItem(a.id);

        await repository.reorderItem(
          sectionId: sectionId,
          oldIndex: 1,
          newIndex: 0,
        );

        expect(await orderedContents(), ['C', 'B']);
      },
    );

    test('reordering a single-item list is a no-op', () async {
      await repository.addItem(listId: listId, text: 'A');

      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 0,
        newIndex: 0,
      );

      expect(await orderedContents(), ['A']);
    });

    test('new order persists across a fresh query', () async {
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.reorderItem(
        sectionId: sectionId,
        oldIndex: 0,
        newIndex: 1,
      );

      final reloaded = await DriftListItemRepository(database)
          .watchItems(listId)
          .first;

      expect(reloaded.map((item) => item.content).toList(), ['B', 'A']);
    });

    test('only reorders items within the given section', () async {
      final otherSectionId = 'section-2';
      await database
          .into(database.sections)
          .insert(
            SectionsCompanion.insert(
              id: otherSectionId,
              listId: listId,
              sortOrder: 2000,
            ),
          );
      await repository.addItem(listId: listId, text: 'A');
      await repository.addItem(listId: listId, text: 'B');
      await repository.addItemToSection(sectionId: otherSectionId, text: 'X');
      await repository.addItemToSection(sectionId: otherSectionId, text: 'Y');

      await repository.reorderItem(
        sectionId: otherSectionId,
        oldIndex: 0,
        newIndex: 1,
      );

      expect(await orderedContents(), ['A', 'B', 'Y', 'X']);
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

  group('getItems', () {
    test('reads the current items in the same order as watchItems', () async {
      await repository.addItem(listId: listId, text: 'Milk');
      await repository.addItem(listId: listId, text: 'Eggs');

      final items = await repository.getItems(listId);

      expect(items.map((i) => i.content).toList(), ['Milk', 'Eggs']);
    });
  });
}
