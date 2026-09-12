import 'package:promptlist/core/database/app_database.dart';

/// Thrown when a template operation fails validation, or would edit a
/// built-in template (built-ins are immutable --- see TASK-031).
class TemplateValidationException implements Exception {
  const TemplateValidationException(this.message);

  final String message;

  @override
  String toString() => 'TemplateValidationException: $message';
}

/// One section's worth of input when constructing a template's
/// structure in a single call --- used for seeding built-in templates
/// and for saving an existing list as a template.
class TemplateSectionInput {
  const TemplateSectionInput({this.title, this.items = const []});

  final String? title;
  final List<String> items;
}

/// A template section paired with its items, in display order.
class TemplateSectionWithItems {
  const TemplateSectionWithItems({required this.section, required this.items});

  final TemplateSectionRecord section;
  final List<TemplateItemRecord> items;
}

/// A template's full reusable structure.
class TemplateWithSections {
  const TemplateWithSections({required this.template, required this.sections});

  final TemplateRecord template;
  final List<TemplateSectionWithItems> sections;
}

/// Provider-independent persistence contract for reusable templates.
///
/// Templates are constructed and read as a whole structure rather than
/// through per-section/per-item CRUD: nothing in the product requires
/// editing a template's items interactively (see PLAN.md Milestone 3),
/// only creating one wholesale (built-ins, or "save list as
/// template") and reading it wholesale (to instantiate a list from
/// it).
abstract interface class TemplateRepository {
  /// Emits every template (built-in and user), ordered for display.
  Stream<List<TemplateRecord>> watchTemplates();

  /// Emits the template identified by [templateId] with its full
  /// section/item structure, or `null` if it does not exist.
  Stream<TemplateWithSections?> watchTemplate(String templateId);

  /// Reads the template identified by [templateId] with its full
  /// section/item structure once, or `null` if it does not exist.
  Future<TemplateWithSections?> getTemplate(String templateId);

  /// Creates a template named [name] with the given [sections],
  /// atomically. [isBuiltIn] marks it as immutable (see
  /// [renameTemplate], [deleteTemplate]).
  ///
  /// Throws [TemplateValidationException] if [name] is blank.
  Future<TemplateRecord> createTemplate({
    required String name,
    String? description,
    bool isBuiltIn = false,
    List<TemplateSectionInput> sections = const [],
  });

  /// Renames the template identified by [templateId].
  ///
  /// Throws [TemplateValidationException] if [name] is blank, or if
  /// the template is built-in.
  Future<void> renameTemplate({
    required String templateId,
    required String name,
  });

  /// Deletes the template identified by [templateId] and (via
  /// cascade) its sections/items.
  ///
  /// Throws [TemplateValidationException] if the template is built-in.
  Future<void> deleteTemplate(String templateId);
}
