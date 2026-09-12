import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/app/root_shell.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/settings/presentation/settings_screen.dart';

import '../support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Widget wrap(Widget child) =>
      wrapWithProviders(MaterialApp(home: child), database: database);

  driftTestWidgets('starts on the Lists destination', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    expect(find.widgetWithText(AppBar, 'Lists'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget); // nav label only
    expect(find.text('AI Create'), findsOneWidget); // nav label only
  });

  driftTestWidgets('switches to Templates when tapped', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'Templates'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Templates'), findsOneWidget);
  });

  driftTestWidgets('switches to AI Create when tapped', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'AI Create'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'AI Create'), findsOneWidget);
  });

  driftTestWidgets('navigation selection persists across rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'Templates'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Templates'), findsOneWidget);
  });

  driftTestWidgets('opens Settings from the app bar without a nav tab', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const RootShell()));

    expect(find.text('Settings'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.widgetWithText(AppBar, 'Lists'), findsOneWidget);
  });
}
