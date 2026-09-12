import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:promptlist/features/ai_generation/data/openai_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_failure.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';

http.Response _chatCompletionResponse(Object content, {int statusCode = 200}) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': content is String ? content : jsonEncode(content),
          },
        },
      ],
    }),
    statusCode,
  );
}

void main() {
  group('OpenAiListGenerationService', () {
    test('rejects a blank prompt without making a network call', () async {
      var callCount = 0;
      final service = OpenAiListGenerationService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          callCount++;
          return _chatCompletionResponse('{}');
        }),
      );

      final result = await service.generateList('   ');

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.invalidPrompt,
      );
      expect(callCount, 0);
    });

    test(
      'sends the prompt and API key, and validates a good response',
      () async {
        http.Request? capturedRequest;
        final service = OpenAiListGenerationService(
          apiKey: 'secret-key',
          client: MockClient((request) async {
            capturedRequest = request;
            return _chatCompletionResponse({
              'title': 'Camping trip',
              'sections': [
                {
                  'items': [
                    {'text': 'Tent'},
                    {'text': 'Sleeping bag'},
                  ],
                },
              ],
            });
          }),
        );

        final result = await service.generateList('Pack for camping');

        expect(result, isA<AiGenerationSuccess>());
        final list = (result as AiGenerationSuccess).list;
        expect(list.title, 'Camping trip');
        expect(list.sections.single.items.map((i) => i.text), [
          'Tent',
          'Sleeping bag',
        ]);

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.headers['Authorization'], 'Bearer secret-key');
        final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages.last['content'], 'Pack for camping');
      },
    );

    test(
      'maps an invalid/malformed generated payload through the validator',
      () async {
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          client: MockClient((request) async {
            return _chatCompletionResponse('{"title": ""}');
          }),
        );

        final result = await service.generateList('anything');

        expect(result, isA<AiGenerationError>());
        expect(
          (result as AiGenerationError).failure.type,
          AiGenerationFailureType.invalidResponse,
        );
      },
    );

    test('maps a non-JSON response body to invalidResponse', () async {
      final service = OpenAiListGenerationService(
        apiKey: 'k',
        client: MockClient((request) async {
          return http.Response('not json at all', 200);
        }),
      );

      final result = await service.generateList('anything');

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.invalidResponse,
      );
    });

    test(
      'maps a response missing message content to invalidResponse',
      () async {
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          client: MockClient((request) async {
            return http.Response(jsonEncode({'choices': <Object?>[]}), 200);
          }),
        );

        final result = await service.generateList('anything');

        expect(result, isA<AiGenerationError>());
        expect(
          (result as AiGenerationError).failure.type,
          AiGenerationFailureType.invalidResponse,
        );
      },
    );

    test('maps HTTP 429 to a rateLimited failure', () async {
      final service = OpenAiListGenerationService(
        apiKey: 'k',
        client: MockClient((request) async {
          return http.Response('{}', 429);
        }),
      );

      final result = await service.generateList('anything');

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.rateLimited,
      );
    });

    test(
      'maps other non-200 status codes to a providerError failure',
      () async {
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          client: MockClient((request) async {
            return http.Response('{"error": "invalid api key"}', 401);
          }),
        );

        final result = await service.generateList('anything');

        expect(result, isA<AiGenerationError>());
        expect(
          (result as AiGenerationError).failure.type,
          AiGenerationFailureType.providerError,
        );
      },
    );

    test('maps a client-thrown exception to a network failure', () async {
      final service = OpenAiListGenerationService(
        apiKey: 'k',
        client: MockClient((request) async {
          throw const SocketExceptionStub();
        }),
      );

      final result = await service.generateList('anything');

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.network,
      );
    });

    test(
      'maps a slow response past the timeout to a timeout failure',
      () async {
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          timeout: const Duration(milliseconds: 20),
          client: MockClient((request) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return _chatCompletionResponse('{}');
          }),
        );

        final result = await service.generateList('anything');

        expect(result, isA<AiGenerationError>());
        expect(
          (result as AiGenerationError).failure.type,
          AiGenerationFailureType.timeout,
        );
      },
    );
  });

  group('OpenAiListGenerationService.modifyList', () {
    const snapshot = GeneratedList(
      title: 'Groceries',
      sections: [
        GeneratedSection(items: [GeneratedItem(text: 'Milk')]),
      ],
    );

    test('rejects a blank instruction without making a network call', () async {
      var callCount = 0;
      final service = OpenAiListGenerationService(
        apiKey: 'k',
        client: MockClient((request) async {
          callCount++;
          return _chatCompletionResponse('{}');
        }),
      );

      final result = await service.modifyList(
        snapshot: snapshot,
        instruction: '   ',
      );

      expect(result, isA<AiGenerationError>());
      expect(
        (result as AiGenerationError).failure.type,
        AiGenerationFailureType.invalidPrompt,
      );
      expect(callCount, 0);
    });

    test(
      'sends the snapshot and instruction, and validates a good response',
      () async {
        http.Request? capturedRequest;
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          client: MockClient((request) async {
            capturedRequest = request;
            return _chatCompletionResponse({
              'title': 'Groceries',
              'sections': [
                {
                  'items': [
                    {'text': 'Milk'},
                    {'text': 'Eggs'},
                  ],
                },
              ],
            });
          }),
        );

        final result = await service.modifyList(
          snapshot: snapshot,
          instruction: 'add eggs',
        );

        expect(result, isA<AiGenerationSuccess>());
        final list = (result as AiGenerationSuccess).list;
        expect(list.sections.single.items.map((i) => i.text), ['Milk', 'Eggs']);

        final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        final userMessage =
            (body['messages'] as List).last['content'] as String;
        expect(userMessage, contains('"title":"Groceries"'));
        expect(userMessage, contains('"text":"Milk"'));
        expect(userMessage, contains('add eggs'));
      },
    );

    test(
      'an invalid modification response maps through the validator',
      () async {
        final service = OpenAiListGenerationService(
          apiKey: 'k',
          client: MockClient((request) async {
            return _chatCompletionResponse('{"title": ""}');
          }),
        );

        final result = await service.modifyList(
          snapshot: snapshot,
          instruction: 'add eggs',
        );

        expect(result, isA<AiGenerationError>());
        expect(
          (result as AiGenerationError).failure.type,
          AiGenerationFailureType.invalidResponse,
        );
      },
    );
  });
}

/// A minimal stand-in for a thrown transport exception (e.g. no network
/// connectivity), without depending on `dart:io`'s `SocketException` in
/// a test that otherwise only needs "the client threw something".
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: no connection';
}
