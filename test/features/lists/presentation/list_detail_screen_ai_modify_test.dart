import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/ai_generation/domain/list_generation_service.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';
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
  });

  tearDown(() => database.close());

  Future<void> pumpDetailScreen(
    WidgetTester tester, {
    required ListGenerationService service,
  }) async {
    await tester.pumpWidget(
      wrapWithProviders(
        ProviderScope(
          overrides: [listGenerationServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: ListDetailScreen(listId: listId)),
        ),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAiModifyDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI to change this list'));
    await tester.pumpAndSettle();
  }

  // The list screen underneath always has its own "Add an item" field,
  // so the instruction field must be found scoped to the dialog.
  Finder dialogTextField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  driftTestWidgets('offers an AI modify action in the list menu', (
    tester,
  ) async {
    await pumpDetailScreen(tester, service: FakeListGenerationService());

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Ask AI to change this list'), findsOneWidget);
  });

  driftTestWidgets(
    'cancelling the instruction dialog leaves the list untouched',
    (tester) async {
      await pumpDetailScreen(tester, service: FakeListGenerationService());

      await openAiModifyDialog(tester);
      expect(find.text('Ask AI to change this list'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsNothing);
      final items = await database.select(database.listItems).get();
      expect(items.single.content, 'Milk');
    },
  );

  driftTestWidgets(
    'submitting an instruction sends the current list as a snapshot and '
    'opens the proposed result for review',
    (tester) async {
      GeneratedList? capturedSnapshot;
      String? capturedInstruction;
      final service = ListGenerationServiceStub(
        modifyResult: (snapshot, instruction) {
          capturedSnapshot = snapshot;
          capturedInstruction = instruction;
          return const AiGenerationSuccess(
            GeneratedList(
              title: 'Groceries',
              sections: [
                GeneratedSection(
                  items: [
                    GeneratedItem(text: 'Milk'),
                    GeneratedItem(text: 'Eggs'),
                  ],
                ),
              ],
            ),
          );
        },
      );

      await pumpDetailScreen(tester, service: service);
      await openAiModifyDialog(tester);

      await tester.enterText(dialogTextField(), 'add eggs');
      await tester.pump();
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();

      expect(capturedInstruction, 'add eggs');
      expect(capturedSnapshot, isNotNull);
      expect(capturedSnapshot!.title, 'Groceries');
      expect(capturedSnapshot!.sections.single.items.single.text, 'Milk');

      expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);
      expect(find.text('Review AI changes'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Apply changes (2 items)'), findsOneWidget);

      // Nothing is applied to the real list yet -- that's TASK-052.
      final items = await database.select(database.listItems).get();
      expect(items, hasLength(1));
      expect(items.single.content, 'Milk');
    },
  );

  driftTestWidgets(
    'cancelling the proposed result preserves the original list exactly',
    (tester) async {
      final service = ListGenerationServiceStub(
        modifyResult: (snapshot, instruction) => const AiGenerationSuccess(
          GeneratedList(
            title: 'Groceries',
            sections: [
              GeneratedSection(items: [GeneratedItem(text: 'Something else')]),
            ],
          ),
        ),
      );

      await pumpDetailScreen(tester, service: service);
      await openAiModifyDialog(tester);

      await tester.enterText(dialogTextField(), 'replace everything');
      await tester.pump();
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsNothing);
      expect(find.text('Milk'), findsOneWidget);
      final items = await database.select(database.listItems).get();
      expect(items.single.content, 'Milk');
    },
  );

  driftTestWidgets('shows an inline error when modification fails', (
    tester,
  ) async {
    final service = ListGenerationServiceStub(
      modifyResult: (snapshot, instruction) => const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.providerError,
          'The provider returned an error.',
        ),
      ),
    );

    await pumpDetailScreen(tester, service: service);
    await openAiModifyDialog(tester);

    await tester.enterText(dialogTextField(), 'add eggs');
    await tester.pump();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    expect(find.text('The provider returned an error.'), findsOneWidget);
    final items = await database.select(database.listItems).get();
    expect(items.single.content, 'Milk');
  });
}

/// A minimal [ListGenerationService]-shaped stub focused on
/// `modifyList`; `generateList` is not used by [ListDetailScreen].
class ListGenerationServiceStub implements ListGenerationService {
  ListGenerationServiceStub({required this.modifyResult});

  final AiGenerationResult Function(GeneratedList snapshot, String instruction)
  modifyResult;

  @override
  Future<AiGenerationResult> generateList(String prompt) {
    throw UnimplementedError('not used in this test');
  }

  @override
  Future<AiGenerationResult> modifyList({
    required GeneratedList snapshot,
    required String instruction,
  }) async {
    return modifyResult(snapshot, instruction);
  }
}
