import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/app/app.dart';
import 'package:promptlist/core/database/app_database.dart';

import 'support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  driftTestWidgets('PromptListApp renders the Lists home shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithProviders(const PromptListApp(), database: database),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Lists'), findsWidgets);
  });

  driftTestWidgets(
    'follows the system light theme, rendering the Lists shell readably',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        wrapWithProviders(const PromptListApp(), database: database),
      );

      final context = tester.element(find.text('Lists').first);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(find.text('Search lists and items'), findsOneWidget);
    },
  );

  driftTestWidgets(
    'follows the system dark theme, rendering the Lists shell readably',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        wrapWithProviders(const PromptListApp(), database: database),
      );

      final context = tester.element(find.text('Lists').first);
      final theme = Theme.of(context);
      expect(theme.brightness, Brightness.dark);
      // A real dark scheme, not the light one left in place: text must
      // remain legible against the (now-dark) surface.
      expect(theme.colorScheme.onSurface, isNot(theme.colorScheme.surface));
      expect(find.text('Search lists and items'), findsOneWidget);
    },
  );
}
