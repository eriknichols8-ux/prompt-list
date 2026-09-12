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

import '../../../support/test_providers.dart';

/// Verifies the no-persist-before-accept rule against the real database:
/// cancelling out of the preview must never create a list/section/item
/// row. (Accepting the preview *does* persist -- see
/// `ai_create_screen_test.dart`'s "accepting the preview creates a real
/// list" test -- which is exactly what makes this cancel-path guarantee
/// worth pinning down on its own.)
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
    expect(await database.select(database.lists).get(), isEmpty);
    expect(await database.select(database.sections).get(), isEmpty);
    expect(await database.select(database.listItems).get(), isEmpty);
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

    expect(find.byType(ListDetailScreen), findsNothing);
    await expectNoListsPersisted();
  });
}
