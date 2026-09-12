import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;
  const listId = 'list-1';
  const firstSectionId = 'section-1';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
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
            id: firstSectionId,
            listId: listId,
            sortOrder: 1000,
          ),
        );
  });

  tearDown(() => database.close());

  Future<void> pumpDetailScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        const MaterialApp(home: ListDetailScreen(listId: listId)),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder dialogTextField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Future<void> addSection(WidgetTester tester, String title) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), title);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  driftTestWidgets('adding a second section shows headers for both sections', (
    tester,
  ) async {
    await pumpDetailScreen(tester);

    expect(find.text('Untitled section'), findsNothing);

    await addSection(tester, 'Dairy');

    expect(find.text('Untitled section'), findsOneWidget);
    expect(find.text('Dairy'), findsOneWidget);
  });

  driftTestWidgets('renaming a section updates its header', (tester) async {
    await pumpDetailScreen(tester);
    await addSection(tester, 'Dairy');

    await tester.tap(find.text('Dairy'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), 'Fridge');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Fridge'), findsOneWidget);
    expect(find.text('Dairy'), findsNothing);
  });

  driftTestWidgets(
    'deleting a section removes it; deleting the last one fails safely',
    (tester) async {
      await pumpDetailScreen(tester);
      await addSection(tester, 'Dairy');
      expect(find.text('Dairy'), findsOneWidget);

      // Sections render in sort order: "Untitled section" (the
      // original default) first, "Dairy" (just added) second, so its
      // delete icon is the last delete_outline in the tree (no items
      // exist yet to add any others).
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Dairy'), findsNothing);
      // Back to a single section: no header shown at all.
      expect(find.text('Untitled section'), findsNothing);

      // With a single section left, the view reverts to the flat,
      // header-less "simple" mode (PRODUCT_SPEC.md section 8) --- there
      // is no section-delete control to even offer, so the repository's
      // "can't delete the only section" guard is unreachable from here
      // by construction. That guard itself is covered directly at the
      // repository layer (drift_section_repository_test.dart).
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    },
  );

  driftTestWidgets('reordering sections with the up/down controls', (
    tester,
  ) async {
    await pumpDetailScreen(tester);
    await addSection(tester, 'Dairy');

    expect(
      tester.getTopLeft(find.text('Untitled section')).dy,
      lessThan(tester.getTopLeft(find.text('Dairy')).dy),
    );

    await tester.tap(find.byTooltip('Move section down').first);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Dairy')).dy,
      lessThan(tester.getTopLeft(find.text('Untitled section')).dy),
    );
  });

  driftTestWidgets('moving an item to another section relocates it', (
    tester,
  ) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: firstSectionId,
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);
    await addSection(tester, 'Dairy');

    await tester.tap(find.byIcon(Icons.drive_file_move_outline));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Dairy'),
      ),
    );
    await tester.pumpAndSettle();

    final milkItem = await (database.select(
      database.listItems,
    )..where((tbl) => tbl.id.equals('item-1'))).getSingle();
    final dairySection = await (database.select(
      database.sections,
    )..where((tbl) => tbl.title.equals('Dairy'))).getSingle();
    expect(milkItem.sectionId, dairySection.id);
  });
}
