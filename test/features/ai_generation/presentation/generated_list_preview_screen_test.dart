import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';

const _sample = GeneratedList(
  title: 'Marvel Movies in Chronological Order',
  description: 'Ordered by in-universe chronology.',
  sections: [
    GeneratedSection(
      title: 'Phase One',
      items: [
        GeneratedItem(text: 'Captain America: The First Avenger'),
        GeneratedItem(text: 'Iron Man'),
      ],
    ),
    GeneratedSection(title: null, items: [GeneratedItem(text: 'Loose end')]),
  ],
);

Finder _removeButtonFor(String itemText) => find.descendant(
  of: find.widgetWithText(ListTile, itemText),
  matching: find.byIcon(Icons.remove_circle_outline),
);

void main() {
  testWidgets('shows the title, section titles, and items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GeneratedListPreviewScreen(initial: _sample)),
    );

    expect(find.text('Marvel Movies in Chronological Order'), findsOneWidget);
    expect(find.text('Phase One'), findsOneWidget);
    expect(find.text('Captain America: The First Avenger'), findsOneWidget);
    expect(find.text('Iron Man'), findsOneWidget);
    expect(find.text('Loose end'), findsOneWidget);
    expect(find.text('Add to my lists (3 items)'), findsOneWidget);
  });

  testWidgets('removing an item hides it and updates the item count', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GeneratedListPreviewScreen(initial: _sample)),
    );

    await tester.tap(_removeButtonFor('Iron Man'));
    await tester.pump();

    expect(find.text('Iron Man'), findsNothing);
    expect(find.text('Add to my lists (2 items)'), findsOneWidget);
  });

  testWidgets('accept button is disabled once every item is removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GeneratedListPreviewScreen(
          initial: GeneratedList(
            title: 'Solo item list',
            sections: [
              GeneratedSection(items: [GeneratedItem(text: 'Only item')]),
            ],
          ),
        ),
      ),
    );

    await tester.tap(_removeButtonFor('Only item'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Add to my lists (0 items)'), findsOneWidget);
  });

  testWidgets('accepting returns the edited title and remaining items', (
    tester,
  ) async {
    GeneratedList? accepted;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                accepted = await Navigator.of(context).push<GeneratedList>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const GeneratedListPreviewScreen(initial: _sample),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(_removeButtonFor('Loose end'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '  Renamed list  ');
    await tester.pump();

    await tester.tap(find.text('Add to my lists (2 items)'));
    await tester.pumpAndSettle();

    expect(accepted, isNotNull);
    expect(accepted!.title, 'Renamed list');
    expect(accepted!.sections, hasLength(1));
    expect(accepted!.sections.single.items.map((i) => i.text), [
      'Captain America: The First Avenger',
      'Iron Man',
    ]);
  });

  testWidgets('cancelling pops with no result and discards edits', (
    tester,
  ) async {
    GeneratedList? accepted;
    var pushCompleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                accepted = await Navigator.of(context).push<GeneratedList>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const GeneratedListPreviewScreen(initial: _sample),
                  ),
                );
                pushCompleted = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Edit, then cancel: the edit must not survive.
    await tester.tap(_removeButtonFor('Iron Man'));
    await tester.pump();

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(pushCompleted, isTrue);
    expect(accepted, isNull);
  });
}
