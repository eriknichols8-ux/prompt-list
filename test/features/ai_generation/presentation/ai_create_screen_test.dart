import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/ai_generation/domain/list_generation_service.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_create_screen.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';

/// A [ListGenerationService] whose response is controlled by an external
/// [Completer], so tests can assert on the loading/cancel states before
/// choosing when (and how) the request resolves.
class _ControllableGenerationService implements ListGenerationService {
  Completer<AiGenerationResult>? pending;

  @override
  Future<AiGenerationResult> generateList(String prompt) {
    final completer = Completer<AiGenerationResult>();
    pending = completer;
    return completer.future;
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  ListGenerationService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [listGenerationServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: Scaffold(body: AiCreateScreen())),
    ),
  );
}

void main() {
  testWidgets('submit is disabled until a prompt is entered', (tester) async {
    await pumpScreen(tester, FakeListGenerationService());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();

    final enabledButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('rejects a whitespace-only prompt', (tester) async {
    await pumpScreen(tester, FakeListGenerationService());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('successful generation opens the preview screen', (tester) async {
    await pumpScreen(tester, FakeListGenerationService());

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);
    expect(find.text('First item'), findsOneWidget);
    expect(find.text('Second item'), findsOneWidget);
    expect(find.text('Third item'), findsOneWidget);
  });

  testWidgets('shows a typed error message when generation fails', (
    tester,
  ) async {
    final service = FakeListGenerationService(
      onGenerate: (_) => const AiGenerationError(
        AiGenerationFailure(
          AiGenerationFailureType.providerError,
          'The provider returned an error.',
        ),
      ),
    );
    await pumpScreen(tester, service);

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    expect(find.text('The provider returned an error.'), findsOneWidget);
    // The prompt entry remains so the user can retry.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(GeneratedListPreviewScreen), findsNothing);
  });

  testWidgets(
    'shows a loading state and blocks duplicate submission while generating',
    (tester) async {
      final service = _ControllableGenerationService();
      await pumpScreen(tester, service);

      await tester.enterText(find.byType(TextField), 'Camping trip');
      await tester.pump();
      await tester.tap(find.text('Make me a list'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Make me a list'), findsNothing);

      service.pending!.complete(
        const AiGenerationSuccess(
          GeneratedList(
            title: 'Camping trip',
            sections: [
              GeneratedSection(items: [GeneratedItem(text: 'Tent')]),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsOneWidget);
      expect(find.text('Tent'), findsOneWidget);
    },
  );

  testWidgets('cancelling while generating discards a late result', (
    tester,
  ) async {
    final service = _ControllableGenerationService();
    await pumpScreen(tester, service);

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pump();

    final pendingCompleter = service.pending!;
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    // Back to prompt entry immediately after cancelling.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The cancelled request resolving later must not resurrect a result
    // or open a preview for it.
    pendingCompleter.complete(
      const AiGenerationSuccess(
        GeneratedList(
          title: 'Camping trip',
          sections: [
            GeneratedSection(items: [GeneratedItem(text: 'Tent')]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(GeneratedListPreviewScreen), findsNothing);
  });

  testWidgets('accepting the preview returns to prompt entry and clears it', (
    tester,
  ) async {
    await pumpScreen(tester, FakeListGenerationService());

    await tester.enterText(find.byType(TextField), 'Camping trip');
    await tester.pump();
    await tester.tap(find.text('Make me a list'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to my lists (3 items)'));
    await tester.pumpAndSettle();

    expect(find.byType(GeneratedListPreviewScreen), findsNothing);
    expect(find.text('List accepted.'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets(
    'cancelling the preview returns to prompt entry with the prompt intact',
    (tester) async {
      await pumpScreen(tester, FakeListGenerationService());

      await tester.enterText(find.byType(TextField), 'Camping trip');
      await tester.pump();
      await tester.tap(find.text('Make me a list'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(GeneratedListPreviewScreen), findsNothing);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Camping trip');
    },
  );
}
