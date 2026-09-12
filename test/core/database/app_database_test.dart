import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('opens at the current schema version', () {
    expect(database.schemaVersion, 2);
  });

  test('creates and reads a list', () async {
    final now = DateTime.now();
    await database
        .into(database.lists)
        .insert(
          ListsCompanion.insert(
            id: 'list-1',
            title: 'Groceries',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final rows = await database.select(database.lists).get();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'list-1');
    expect(rows.single.title, 'Groceries');
    expect(rows.single.description, isNull);
    expect(rows.single.archivedAt, isNull);
  });

  test('creates a section under a list and reads it back', () async {
    final now = DateTime.now();
    await database
        .into(database.lists)
        .insert(
          ListsCompanion.insert(
            id: 'list-1',
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
            listId: 'list-1',
            sortOrder: 1000,
          ),
        );

    final sections = await database.select(database.sections).get();

    expect(sections, hasLength(1));
    expect(sections.single.listId, 'list-1');
    expect(sections.single.title, isNull);
    expect(sections.single.sortOrder, 1000);
  });

  test(
    'creates a list item under a section with completion and order',
    () async {
      final now = DateTime.now();
      await database
          .into(database.lists)
          .insert(
            ListsCompanion.insert(
              id: 'list-1',
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
              listId: 'list-1',
              sortOrder: 1000,
            ),
          );
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              sectionId: 'section-1',
              content: 'Milk',
              sortOrder: 1000,
              createdAt: now,
            ),
          );

      final items = await database.select(database.listItems).get();

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.content, 'Milk');
      expect(item.completed, isFalse);
      expect(item.sortOrder, 1000);
      expect(item.completedAt, isNull);
    },
  );

  test('deleting a list cascades to its sections and items', () async {
    final now = DateTime.now();
    await database
        .into(database.lists)
        .insert(
          ListsCompanion.insert(
            id: 'list-1',
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
            listId: 'list-1',
            sortOrder: 1000,
          ),
        );
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: now,
          ),
        );

    await (database.delete(
      database.lists,
    )..where((tbl) => tbl.id.equals('list-1'))).go();

    expect(await database.select(database.lists).get(), isEmpty);
    expect(await database.select(database.sections).get(), isEmpty);
    expect(await database.select(database.listItems).get(), isEmpty);
  });
}
