import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/database/database_provider.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

/// The app-wide [TemplateRepository] instance.
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return DriftTemplateRepository(ref.watch(appDatabaseProvider));
});

/// Reactive stream of every template (built-in and user), for the
/// Templates browsing screen.
final templatesProvider = StreamProvider<List<TemplateRecord>>((ref) {
  return ref.watch(templateRepositoryProvider).watchTemplates();
});

/// A single template with its full section/item structure, for the
/// template preview screen.
final templateProvider = StreamProvider.family<TemplateWithSections?, String>((
  ref,
  templateId,
) {
  return ref.watch(templateRepositoryProvider).watchTemplate(templateId);
});
