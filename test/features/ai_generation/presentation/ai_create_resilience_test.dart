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
import 'package:promptlist/features/ai_generation/presentation/ai_create_screen.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

import '../../../support/test_providers.dart';

/// A [ListRepository] that fails to save a generated list, so tests can
/// verify the accept-time failure path without a real storage error.
class _ThrowingListRepository implements ListRepository {
  @override
  Future<ListRecord> createListFromGeneratedList(GeneratedList generated) {
    throw Exception('disk full');
  }

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

/// A [ListGenerationService] that counts how many times it was actually
/// invoked, for asserting a rapid double-tap only issues one request.
class _CountingGenerationService implements ListGenerationService {
  _CountingGenerationService(this._result);

  final AiGenerationResult _result;
  int callCount = 0;

  @override
  Future<AiGenerationResult> generateList(String prompt) async {
    callCount++;
    // A short async gap so a second, near-simultaneous tap has a chance
    // to slip through if the duplicate-submission guard were missing.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return _result;
  }
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  driftTestWidgets('a failed generation leaves existing lists untouched', (
    tester,
  ) async {
    final repository = DriftListRepository(database);
    final existing = await repository.createList(title: 'Groceries');

    await tester.pumpWidget(
      wrapWithProviders(
        ProviderScope(
          overrides: [
            listGenerationServiceProvider.overrideWithValue(
              FakeListGenerationService(
                onGenerate: (_) => const AiGenerationError(
                  AiGenerationFailure(
                    AiGenerationFailureType.providerError,
                    'The provider returned an error.',
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: AiCreateScreen())),
        ),
        database: database,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    expect(find.text('The provider returned an error.'), findsOneWidget);

    final lists = await database.select(database.lists).get();
    expect(lists, hasLength(1));
    expect(lists.single.id, existing.id);
    expect(lists.single.title, 'Groceries');
  });

  testWidgets('a failure while saving an accepted list shows an inline error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listGenerationServiceProvider.overrideWithValue(
            FakeListGenerationService(),
          ),
          listRepositoryProvider.overrideWithValue(_ThrowingListRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: AiCreateScreen())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to my lists (3 items)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the generated list. Please try again.'),
      findsOneWidget,
    );
    // The prompt is still there so the user can try accepting again.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a rapid double-tap only issues a single generation request', (
    tester,
  ) async {
    final service = _CountingGenerationService(
      const AiGenerationSuccess(
        GeneratedList(
          title: 'Camping trip',
          sections: [
            GeneratedSection(items: [GeneratedItem(text: 'Tent')]),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [listGenerationServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: Scaffold(body: AiCreateScreen())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();

    // Two taps back-to-back, before either has a chance to rebuild the
    // button into its disabled loading state.
    await tester.tap(find.text('Make me a list'));
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
  });
}
