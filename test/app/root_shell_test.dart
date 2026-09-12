import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/app/root_shell.dart';
import 'package:promptlist/features/settings/presentation/settings_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('starts on the Lists destination', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    expect(find.widgetWithText(AppBar, 'Lists'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget); // nav label only
    expect(find.text('AI Create'), findsOneWidget); // nav label only
  });

  testWidgets('switches to Templates when tapped', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'Templates'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Templates'), findsOneWidget);
  });

  testWidgets('switches to AI Create when tapped', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'AI Create'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'AI Create'), findsOneWidget);
  });

  testWidgets('navigation selection persists across rebuilds', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));

    await tester.tap(find.widgetWithText(NavigationDestination, 'Templates'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Templates'), findsOneWidget);
  });

  testWidgets('opens Settings from the app bar without a nav tab', (
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
