import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_create_screen.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';

import '../support/test_providers.dart';

/// Critical flows 3 and 4 from `docs/TESTING.md`, using the
/// deterministic `FakeListGenerationService` -- never a live provider,
/// per this project's testing rules.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpAiCreateScreen(WidgetTester tester) async {
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
    await tester.pumpAndSettle();
  }

  driftTestWidgets(
    'flow 3: fake AI prompt -> preview -> accept -> saved, fully normal list',
    (tester) async {
      await pumpAiCreateScreen(tester);

      await tester.enterText(find.byType(TextField), 'Camping trip');
      await tester.pump();
      await tester.tap(find.text('Make me a list'));
      await tester.pumpAndSettle();
      expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);

      await tester.tap(find.text('Add to my lists (3 items)'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsNothing);
      expect(find.byType(ListDetailScreen), findsOneWidget);

      final lists = await database.select(database.lists).get();
      expect(lists, hasLength(1));
      expect(lists.single.title, 'Camping trip');
      final items = await database.select(database.listItems).get();
      expect(items, hasLength(3));
      expect(items.every((i) => !i.completed), isTrue);

      // Behaves exactly like a manually-created list from here on: can
      // be checked off, and that sticks.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final updatedItems = await database.select(database.listItems).get();
      expect(updatedItems.where((i) => i.completed), hasLength(1));
    },
  );

  driftTestWidgets(
    'flow 4: fake AI prompt -> preview -> cancel -> nothing is saved',
    (tester) async {
      await pumpAiCreateScreen(tester);

      await tester.enterText(find.byType(TextField), 'Camping trip');
      await tester.pump();
      await tester.tap(find.text('Make me a list'));
      await tester.pumpAndSettle();
      expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsNothing);
      expect(find.byType(ListDetailScreen), findsNothing);
      expect(await database.select(database.lists).get(), isEmpty);
      expect(await database.select(database.sections).get(), isEmpty);
      expect(await database.select(database.listItems).get(), isEmpty);
    },
  );
}
