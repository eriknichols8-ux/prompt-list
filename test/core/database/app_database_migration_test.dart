import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart'
    hide ListsCompanion, SectionsCompanion, ListItemsCompanion;

import 'fixtures/v1_database.dart';

void main() {
  test(
    'migrating from v1 to v2 preserves data and adds template tables',
    () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'promptlist_migration',
      );
      final dbFile = File('${tempDir.path}/v1.sqlite');
      addTearDown(() => tempDir.delete(recursive: true));

      final now = DateTime.now();

      // Build a representative v1 database: one list, one section, one
      // (completed) item.
      final v1 = V1Database(NativeDatabase(dbFile));
      await v1
          .into(v1.lists)
          .insert(
            ListsCompanion.insert(
              id: 'list-1',
              title: 'Groceries',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v1
          .into(v1.sections)
          .insert(
            SectionsCompanion.insert(
              id: 'section-1',
              listId: 'list-1',
              sortOrder: 1000,
            ),
          );
      await v1
          .into(v1.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              sectionId: 'section-1',
              content: 'Milk',
              sortOrder: 1000,
              createdAt: now,
              completed: const Value(true),
            ),
          );
      await v1.close();

      // Open the same file with the current (v2) database; this must
      // run the v1->v2 migration.
      final v2 = AppDatabase(NativeDatabase(dbFile));
      addTearDown(v2.close);

      final lists = await v2.select(v2.lists).get();
      expect(lists, hasLength(1));
      expect(lists.single.title, 'Groceries');

      final sections = await v2.select(v2.sections).get();
      expect(sections, hasLength(1));
      expect(sections.single.listId, 'list-1');

      final items = await v2.select(v2.listItems).get();
      expect(items, hasLength(1));
      expect(items.single.content, 'Milk');
      expect(items.single.completed, isTrue);

      // The new template tables exist and are usable.
      expect(await v2.select(v2.templates).get(), isEmpty);
      await v2
          .into(v2.templates)
          .insert(
            TemplatesCompanion.insert(
              id: 'template-1',
              name: 'Packing list',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final templates = await v2.select(v2.templates).get();
      expect(templates, hasLength(1));
      expect(templates.single.isBuiltIn, isFalse);
    },
  );
}
