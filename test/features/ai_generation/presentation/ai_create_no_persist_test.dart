import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_create_screen.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';

import '../../../support/test_providers.dart';

/// Verifies the no-persist-before-accept rule end to end through the
/// real database: cancelling out of the preview, and even accepting it,
/// must never create a list/section/item row, since turning an accepted
/// preview into persisted rows isn't wired up until TASK-044.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        ProviderScope(
          overrides: [
            listGenerationServiceProvider.overrideWithValue(
              FakeListGenerationService(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: AiCreateScreen())),
        ),
        database: database,
      ),
    );
  }

  Future<void> expectNoListsPersisted() async {
    final lists = await database.select(database.lists).get();
    final sections = await database.select(database.sections).get();
    final items = await database.select(database.listItems).get();
    expect(lists, isEmpty);
    expect(sections, isEmpty);
    expect(items, isEmpty);
  }

  testWidgets('cancelling the preview creates no database records', (
    tester,
  ) async {
    await pumpApp(tester);
    await expectNoListsPersisted();

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    await expectNoListsPersisted();
  });

  testWidgets('accepting the preview still creates no database records '
      '(persistence is wired up in TASK-044)', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);

    await tester.tap(find.text('Add to my lists (3 items)'));
    await tester.pumpAndSettle();

    await expectNoListsPersisted();
  });
}
