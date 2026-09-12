import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/lists/presentation/lists_screen.dart';

import '../support/test_providers.dart';

/// Critical flow 1 from `docs/TESTING.md`: manual list -> add/reorder/
/// complete -> restart/reload -> state preserved.
///
/// "Restart" is simulated the way a widget test can: the item screen is
/// torn down entirely and a fresh one is pumped for the same list id,
/// against the same underlying (in-memory) database -- proving the
/// state survived independently of any in-widget-memory state, not
/// just that a single long-lived widget kept it around.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  driftTestWidgets(
    'create manual list, add/reorder/complete items, survives a reload',
    (tester) async {
      // Create the list from the Lists home screen, via the FAB, like a
      // real user would.
      await tester.pumpWidget(
        wrapWithProviders(
          const MaterialApp(home: Scaffold(body: ListsScreen())),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      final createField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(createField, 'Weekend Chores');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(ListDetailScreen), findsOneWidget);
      final listId = (await database.select(database.lists).get()).single.id;

      // Add three items.
      for (final text in ['Mow lawn', 'Wash car', 'Vacuum']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
      }
      expect(find.text('Mow lawn'), findsOneWidget);
      expect(find.text('Wash car'), findsOneWidget);
      expect(find.text('Vacuum'), findsOneWidget);

      // Reorder: move the first item ("Mow lawn") down past "Wash car".
      // Uses the accessible reorder action (TASK-062) rather than a
      // pixel-distance drag gesture, which is exercised precisely
      // enough elsewhere (list_detail_screen_test.dart) and is
      // inherently sensitive to exact row-height math here.
      final moveDown = _customActionsFor(
        tester,
        'Mow lawn',
      ).keys.firstWhere((action) => action.label == 'Move down');
      _customActionsFor(tester, 'Mow lawn')[moveDown]!();
      await tester.pumpAndSettle();

      final orderedAfterReorder = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(orderedAfterReorder, ['Wash car', 'Mow lawn', 'Vacuum']);

      // Complete "Vacuum".
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Vacuum'),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();

      // "Restart": tear down the widget tree entirely and pump a brand
      // new screen for the same list id, against the same database.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(
        wrapWithProviders(
          MaterialApp(home: ListDetailScreen(listId: listId)),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      final orderedAfterReload = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(orderedAfterReload, ['Wash car', 'Mow lawn', 'Vacuum']);

      final vacuumCheckbox = tester.widget<Checkbox>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Vacuum'),
          matching: find.byType(Checkbox),
        ),
      );
      expect(vacuumCheckbox.value, isTrue);

      final washCarCheckbox = tester.widget<Checkbox>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Wash car'),
          matching: find.byType(Checkbox),
        ),
      );
      expect(washCarCheckbox.value, isFalse);
    },
  );
}

/// Reads the move up/down custom semantics actions off the `Semantics`
/// widget wrapping an item row (see `_ItemRow` in
/// `list_detail_screen.dart`). Several ancestor `Semantics` widgets
/// exist above any given text (Flutter adds its own implicit ones), so
/// this picks the one that actually declares custom actions.
Map<CustomSemanticsAction, VoidCallback> _customActionsFor(
  WidgetTester tester,
  String itemText,
) {
  final candidates = tester.widgetList<Semantics>(
    find.ancestor(of: find.text(itemText), matching: find.byType(Semantics)),
  );
  for (final widget in candidates) {
    final actions = widget.properties.customSemanticsActions;
    if (actions != null && actions.isNotEmpty) return actions;
  }
  throw StateError('No custom semantics actions found for "$itemText"');
}
