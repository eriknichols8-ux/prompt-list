import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';
import 'package:promptlist/features/templates/presentation/template_detail_screen.dart';
import 'package:promptlist/features/templates/presentation/templates_screen.dart';

import '../support/test_providers.dart';

/// Critical flow 2 from `docs/TESTING.md`: template -> instantiate ->
/// edit list -> template unchanged.
void main() {
  late AppDatabase database;
  late DriftTemplateRepository templateRepository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    templateRepository = DriftTemplateRepository(database);
    await templateRepository.createTemplate(
      name: 'Grocery Run',
      sections: const [
        TemplateSectionInput(items: ['Milk', 'Eggs']),
      ],
    );
  });

  tearDown(() => database.close());

  driftTestWidgets('creating a list from a template and editing it leaves the '
      'template untouched', (tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        const MaterialApp(home: Scaffold(body: TemplatesScreen())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grocery Run'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateDetailScreen), findsOneWidget);

    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();
    expect(find.byType(ListDetailScreen), findsOneWidget);

    // Edit the new list independently of the template: complete an
    // item and add a new one.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Milk'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bread');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);

    // The template's own rows must be completely unaffected: no
    // completion state (templates never carry any), same two items,
    // no "Bread".
    final template = await templateRepository.getTemplate(
      (await database.select(database.templates).get()).single.id,
    );
    expect(template!.sections.single.items.map((i) => i.content).toList(), [
      'Milk',
      'Eggs',
    ]);

    // Confirmed through the UI too: reopening the template preview
    // shows the original, unedited structure.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grocery Run'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);
  });
}
