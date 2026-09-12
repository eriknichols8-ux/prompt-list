import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/features/ai_generation/data/fake_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';

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
}
