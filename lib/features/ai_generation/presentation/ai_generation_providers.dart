import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_list_generation_service.dart';
import '../domain/list_generation_service.dart';

/// Provides the [ListGenerationService] used by the AI Create screen.
///
/// Defaults to [FakeListGenerationService] until TASK-045 wires up a real
/// provider adapter behind this same interface. Widget tests override
/// this provider with their own scripted fake, so no live provider
/// dependency ever leaks into UI tests.
final listGenerationServiceProvider = Provider<ListGenerationService>((ref) {
  return FakeListGenerationService();
});
