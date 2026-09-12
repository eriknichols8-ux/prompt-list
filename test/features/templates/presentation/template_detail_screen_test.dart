import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';
import 'package:promptlist/features/templates/presentation/template_detail_screen.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;
  late DriftTemplateRepository templateRepository;
  late String templateId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    templateRepository = DriftTemplateRepository(database);
    final template = await templateRepository.createTemplate(
      name: 'Grocery Run',
      description: 'A well-rounded weekly grocery list.',
      sections: const [
        TemplateSectionInput(title: 'Produce', items: ['Bananas', 'Apples']),
        TemplateSectionInput(items: ['Bread']),
      ],
    );
    templateId = template.id;
  });

  tearDown(() => database.close());

  Future<void> pumpDetailScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        MaterialApp(home: TemplateDetailScreen(templateId: templateId)),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  driftTestWidgets(
    'previews the template name, description, sections, and items',
    (tester) async {
      await pumpDetailScreen(tester);

      expect(find.widgetWithText(AppBar, 'Grocery Run'), findsOneWidget);
      expect(find.text('A well-rounded weekly grocery list.'), findsOneWidget);
      expect(find.text('Produce'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
    },
  );

  driftTestWidgets(
    'creating a list copies the structure and leaves the template unchanged',
    (tester) async {
      await pumpDetailScreen(tester);

      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      // TemplateDetailScreen (also showing "Grocery Run"/"Bananas" in
      // its own preview) stays mounted underneath the pushed route, so
      // scope these checks to the new screen specifically.
      final listDetailScreen = find.byType(ListDetailScreen);
      expect(listDetailScreen, findsOneWidget);
      expect(
        find.descendant(
          of: listDetailScreen,
          matching: find.widgetWithText(AppBar, 'Grocery Run'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: listDetailScreen, matching: find.text('Bananas')),
        findsOneWidget,
      );

      final lists = await database.select(database.lists).get();
      expect(lists, hasLength(1));
      expect(lists.single.title, 'Grocery Run');

      final items = await database.select(database.listItems).get();
      expect(items.map((i) => i.content).toSet(), {
        'Bananas',
        'Apples',
        'Bread',
      });
      expect(items.every((i) => !i.completed), isTrue);

      // The template itself is untouched.
      final template = await templateRepository.getTemplate(templateId);
      expect(template!.sections[0].items.map((i) => i.content).toList(), [
        'Bananas',
        'Apples',
      ]);
    },
  );

  driftTestWidgets('renaming a user template updates the app bar', (
    tester,
  ) async {
    await pumpDetailScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'Weekly Groceries');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Weekly Groceries'), findsOneWidget);
  });

  driftTestWidgets(
    'deleting a user template confirms, pops back, and removes it',
    (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TemplateDetailScreen(templateId: templateId),
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
      await tester.tap(find.text('Delete template'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this template?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(find.text('Deleted "Grocery Run"'), findsOneWidget);
      expect(await templateRepository.getTemplate(templateId), isNull);
    },
  );

  driftTestWidgets('a built-in template shows no management menu', (
    tester,
  ) async {
    final builtIn = await templateRepository.createTemplate(
      name: 'Built-in Template',
      isBuiltIn: true,
    );
    await tester.pumpWidget(
      wrapWithProviders(
        MaterialApp(home: TemplateDetailScreen(templateId: builtIn.id)),
        database: database,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
