import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

/// Saves a list's current structure --- its sections and item text, but
/// deliberately never its completion state --- as a new user template
/// named [name].
///
/// Reads through [sectionRepository]/[itemRepository] rather than
/// requiring a combined read model, since nothing else needs one at
/// the domain layer (the equivalent grouping for display already
/// happens in the presentation layer's `sectionsWithItemsProvider`).
Future<TemplateRecord> saveListAsTemplate({
  required SectionRepository sectionRepository,
  required ListItemRepository itemRepository,
  required TemplateRepository templateRepository,
  required String listId,
  required String name,
  String? description,
}) async {
  final sections = await sectionRepository.getSections(listId);
  final items = await itemRepository.getItems(listId);

  final itemsBySection = <String, List<ListItemRecord>>{};
  for (final item in items) {
    itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
  }

  final sectionInputs = [
    for (final section in sections)
      TemplateSectionInput(
        title: section.title,
        items: [
          for (final item in itemsBySection[section.id] ?? const [])
            item.content,
        ],
      ),
  ];

  return templateRepository.createTemplate(
    name: name,
    description: description,
    sections: sectionInputs,
  );
}
