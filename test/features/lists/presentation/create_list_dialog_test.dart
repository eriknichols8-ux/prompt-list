import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/create_list_dialog.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<ListRecord?> pumpAndOpenDialog(WidgetTester tester) async {
    ListRecord? result;
    await tester.pumpWidget(
      wrapWithProviders(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCreateListDialog(context);
                },
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
    return result;
  }

  driftTestWidgets('Create is disabled until a non-blank title is entered', (
    tester,
  ) async {
    await pumpAndOpenDialog(tester);

    FilledButton findCreateButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );

    expect(findCreateButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(findCreateButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.pump();
    expect(findCreateButton().onPressed, isNotNull);
  });

  driftTestWidgets('cancelling creates nothing and returns null', (
    tester,
  ) async {
    ListRecord? result;
    await tester.pumpWidget(
      wrapWithProviders(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCreateListDialog(context);
                },
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

    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(await database.select(database.lists).get(), isEmpty);
  });

  driftTestWidgets('submitting creates the list and returns it', (
    tester,
  ) async {
    ListRecord? result;
    await tester.pumpWidget(
      wrapWithProviders(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCreateListDialog(context);
                },
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

    await tester.enterText(find.byType(TextField), '  Groceries  ');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, 'Groceries');

    final persisted = await database.select(database.lists).get();
    expect(persisted, hasLength(1));
    expect(persisted.single.title, 'Groceries');
  });
}
