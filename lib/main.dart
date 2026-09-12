import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/templates/presentation/template_providers.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(templateRepositoryProvider).seedBuiltInTemplates();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PromptListApp(),
    ),
  );
}
