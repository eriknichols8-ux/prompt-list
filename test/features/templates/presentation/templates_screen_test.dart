import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/templates/presentation/template_detail_screen.dart';
import 'package:promptlist/features/templates/presentation/templates_screen.dart';

import '../../../support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpTemplatesScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        const MaterialApp(home: Scaffold(body: TemplatesScreen())),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
  }

  driftTestWidgets('shows a useful empty state when there are no templates', (
    tester,
  ) async {
    await pumpTemplatesScreen(tester);

    expect(find.text('No templates yet.'), findsOneWidget);
  });

  driftTestWidgets(
    'groups built-in and user templates under separate headings',
    (tester) async {
      final now = DateTime.now();
      await database
          .into(database.templates)
          .insert(
            TemplatesCompanion.insert(
              id: 'template-1',
              name: 'Grocery Run',
              isBuiltIn: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.templates)
          .insert(
            TemplatesCompanion.insert(
              id: 'template-2',
              name: 'My Custom List',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await pumpTemplatesScreen(tester);

      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('My Templates'), findsOneWidget);
      expect(find.text('Grocery Run'), findsOneWidget);
      expect(find.text('My Custom List'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Built-in')).dy,
        lessThan(tester.getTopLeft(find.text('My Templates')).dy),
      );
    },
  );

  driftTestWidgets('omits the "My Templates" heading when there are none', (
    tester,
  ) async {
    final now = DateTime.now();
    await database
        .into(database.templates)
        .insert(
          TemplatesCompanion.insert(
            id: 'template-1',
            name: 'Grocery Run',
            isBuiltIn: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await pumpTemplatesScreen(tester);

    expect(find.text('Built-in'), findsOneWidget);
    expect(find.text('My Templates'), findsNothing);
  });

  driftTestWidgets('tapping a template opens its detail screen', (
    tester,
  ) async {
    final now = DateTime.now();
    await database
        .into(database.templates)
        .insert(
          TemplatesCompanion.insert(
            id: 'template-1',
            name: 'Grocery Run',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await pumpTemplatesScreen(tester);
    await tester.tap(find.text('Grocery Run'));
    await tester.pumpAndSettle();

    expect(find.byType(TemplateDetailScreen), findsOneWidget);
  });
}
