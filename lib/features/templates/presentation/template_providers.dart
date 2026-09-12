import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/database_provider.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

/// The app-wide [TemplateRepository] instance.
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return DriftTemplateRepository(ref.watch(appDatabaseProvider));
});
