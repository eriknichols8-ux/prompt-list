import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/ai_generation/data/openai_list_generation_service.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/templates/presentation/template_providers.dart';

import 'app/app.dart';

/// Populated at build/run time via `--dart-define-from-file=.env` (see
/// `docs/ARCHITECTURE.md`'s "AI Provider Security" section); empty if no
/// `.env` was supplied. Never hard-code a key here.
const _openAiApiKey = String.fromEnvironment('OpenAI_API_Key');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer(
    overrides: [
      // Without a key, the app keeps using the deterministic fake
      // service (see ai_generation_providers.dart) so AI Create still
      // works offline/without setup -- AI is optional, never a hard
      // dependency for ordinary list use.
      if (_openAiApiKey.isNotEmpty)
        listGenerationServiceProvider.overrideWithValue(
          OpenAiListGenerationService(apiKey: _openAiApiKey),
        ),
    ],
  );
  await container.read(templateRepositoryProvider).seedBuiltInTemplates();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PromptListApp(),
    ),
  );
}
