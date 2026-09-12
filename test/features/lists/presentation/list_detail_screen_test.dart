import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;
  const listId = 'list-1';

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
            id: 'section-1',
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

  driftTestWidgets('shows an empty state when the list has no items', (
    tester,
  ) async {
    await pumpDetailScreen(tester);

    expect(find.text('No items yet. Add one below.'), findsOneWidget);
  });

  driftTestWidgets('adding an item shows it and clears the input', (
    tester,
  ) async {
    await pumpDetailScreen(tester);

    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('No items yet. Add one below.'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  driftTestWidgets('the add button is disabled for blank text', (tester) async {
    await pumpDetailScreen(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add),
    );
    expect(button.onPressed, isNull);
  });

  driftTestWidgets('editing an item updates its text', (tester) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Oat milk');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Oat milk'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
  });

  driftTestWidgets('checking and unchecking an item toggles completion', (
    tester,
  ) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);

    Text findLabel() => tester.widget<Text>(find.text('Milk'));
    Checkbox findCheckbox() => tester.widget<Checkbox>(find.byType(Checkbox));

    expect(findCheckbox().value, isFalse);
    expect(findLabel().style?.decoration, isNot(TextDecoration.lineThrough));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(findCheckbox().value, isTrue);
    expect(findLabel().style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(findCheckbox().value, isFalse);
    expect(findLabel().style?.decoration, isNot(TextDecoration.lineThrough));
  });

  driftTestWidgets('dragging the handle reorders items', (tester) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
          ),
        );
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-2',
            sectionId: 'section-1',
            content: 'Eggs',
            sortOrder: 2000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);

    final tiles = find.byType(ListTile);
    expect(
      tester.getTopLeft(tiles.at(0)).dy,
      lessThan(tester.getTopLeft(tiles.at(1)).dy),
    );

    // ReorderableListView needs pumped frames between pointer moves to
    // register the swap; a single tester.drag() call (no intermediate
    // pumps) does not trigger a reorder.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(
          find.descendant(of: tiles, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(texts, ['Eggs', 'Milk']);
  });

  driftTestWidgets('deleting an item removes it from the list', (tester) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('No items yet. Add one below.'), findsOneWidget);
  });

  driftTestWidgets('renaming a list via the menu updates its title', (
    tester,
  ) async {
    await pumpDetailScreen(tester);
    expect(find.widgetWithText(AppBar, 'Groceries'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Weekly Shop');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Weekly Shop'), findsOneWidget);
  });

  driftTestWidgets('clearing completed removes only completed items', (
    tester,
  ) async {
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            sectionId: 'section-1',
            content: 'Milk',
            sortOrder: 1000,
            createdAt: DateTime.now(),
            completed: const Value(true),
          ),
        );
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-2',
            sectionId: 'section-1',
            content: 'Eggs',
            sortOrder: 2000,
            createdAt: DateTime.now(),
          ),
        );

    await pumpDetailScreen(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear completed'));
    await tester.pumpAndSettle();

    expect(find.text('Clear completed items?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('Eggs'), findsOneWidget);
  });

  driftTestWidgets(
    'deleting a list confirms, navigates back, and can be undone',
    (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ListDetailScreen(listId: listId),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          database: database,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this list?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ListDetailScreen), findsNothing);
      expect(find.text('Deleted "Groceries"'), findsOneWidget);

      final archived = await (database.select(
        database.lists,
      )..where((tbl) => tbl.id.equals(listId))).getSingle();
      expect(archived.archivedAt, isNotNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final restored = await (database.select(
        database.lists,
      )..where((tbl) => tbl.id.equals(listId))).getSingle();
      expect(restored.archivedAt, isNull);
    },
  );

  driftTestWidgets(
    'saving as a template copies the current structure, not completion',
    (tester) async {
      await database
          .into(database.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              sectionId: 'section-1',
              content: 'Milk',
              sortOrder: 1000,
              createdAt: DateTime.now(),
              completed: const Value(true),
            ),
          );

      await pumpDetailScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as template'));
      await tester.pumpAndSettle();

      expect(find.text('Save as template'), findsWidgets);
      final dialogField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(dialogField).controller!.text,
        'Groceries',
      );
      await tester.tap(find.text('Save'));
      // _saveAsTemplate's async chain (reading sections/items, then
      // writing the template) isn't tied to anything this screen
      // watches, so no frame gets scheduled while it runs; a plain
      // pumpAndSettle() can return before it finishes. Pump with a
      // real duration a few times to give it room to complete.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Saved as "Groceries"'), findsOneWidget);

      final templates = await database.select(database.templates).get();
      expect(templates, hasLength(1));
      expect(templates.single.name, 'Groceries');

      final templateItems = await database.select(database.templateItems).get();
      expect(templateItems.single.content, 'Milk');
      // Completion state never existed on the template row to begin
      // with; the schema itself has no such column.
    },
  );
}
