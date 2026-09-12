import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/lists/presentation/lists_screen.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> pumpListsScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        const MaterialApp(home: Scaffold(body: ListsScreen())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  driftTestWidgets('shows a useful empty state when there are no lists', (
    tester,
  ) async {
    await pumpListsScreen(tester);

    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.textContaining('template'), findsOneWidget);
  });

  driftTestWidgets('shows saved lists with title and completion progress', (
    tester,
  ) async {
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
    await database
        .into(database.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-2',
            sectionId: 'section-1',
            content: 'Eggs',
            sortOrder: 2000,
            createdAt: now,
            completed: const Value(true),
          ),
        );

    await pumpListsScreen(tester);

    expect(find.text('No lists yet'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('1/2 completed'), findsOneWidget);
  });

  driftTestWidgets('tapping a list opens its detail screen', (tester) async {
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

    await pumpListsScreen(tester);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    expect(find.byType(ListDetailScreen), findsOneWidget);
  });
}
