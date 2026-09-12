import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';

void main() {
  group('FakeListGenerationService', () {
    test('produces a deterministic success for a normal prompt', () async {
      final service = FakeListGenerationService();

      final resultA = await service.generateList('Camping trip');
      final resultB = await service.generateList('Camping trip');

      expect(resultA, isA<AiGenerationSuccess>());
      expect(resultB, isA<AiGenerationSuccess>());
      final listA = (resultA as AiGenerationSuccess).list;
      final listB = (resultB as AiGenerationSuccess).list;
      expect(listA, equals(listB));
      expect(listA.title, 'Camping trip');
      expect(listA.sections.single.items, hasLength(3));
    });

    test('rejects an empty prompt with a typed failure', () async {
      final service = FakeListGenerationService();

      final result = await service.generateList('   ');

      expect(result, isA<AiGenerationError>());
    });

    test('honors an onGenerate override for scripted scenarios', () async {
      final service = FakeListGenerationService(
        onGenerate: (prompt) => const AiGenerationError(
          AiGenerationFailure(AiGenerationFailureType.timeout, 'timed out'),
        ),
      );

      final result = await service.generateList('anything');

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.timeout,
      );
    });
  });

  group('FakeListGenerationService.modifyList', () {
    const snapshot = GeneratedList(
      title: 'Groceries',
      sections: [
        GeneratedSection(items: [GeneratedItem(text: 'Milk')]),
      ],
    );

    test('echoes the snapshot back unchanged by default', () async {
      final service = FakeListGenerationService();

      final result = await service.modifyList(
        snapshot: snapshot,
        instruction: 'add eggs',
      );

      expect(result, isA<AiGenerationSuccess>());
      expect((result as AiGenerationSuccess).list, equals(snapshot));
    });

    test('rejects a blank instruction with a typed failure', () async {
      final service = FakeListGenerationService();

      final result = await service.modifyList(
        snapshot: snapshot,
        instruction: '   ',
      );

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.invalidPrompt,
      );
    });

    test('honors an onModify override for scripted scenarios', () async {
      GeneratedList? capturedSnapshot;
      String? capturedInstruction;
      final service = FakeListGenerationService(
        onModify: (snapshot, instruction) {
          capturedSnapshot = snapshot;
          capturedInstruction = instruction;
          return const AiGenerationSuccess(
            GeneratedList(
              title: 'Groceries',
              sections: [
                GeneratedSection(
                  items: [
                    GeneratedItem(text: 'Milk'),
                    GeneratedItem(text: 'Eggs'),
                  ],
                ),
              ],
            ),
          );
        },
      );

      final result = await service.modifyList(
        snapshot: snapshot,
        instruction: 'add eggs',
      );

      expect(capturedSnapshot, equals(snapshot));
      expect(capturedInstruction, 'add eggs');
      expect(result, isA<AiGenerationSuccess>());
      expect(
        (result as AiGenerationSuccess).list.sections.single.items,
        hasLength(2),
      );
    });
  });
}
