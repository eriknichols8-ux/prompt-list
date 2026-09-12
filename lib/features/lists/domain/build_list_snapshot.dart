import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';

/// Builds a normalized [GeneratedList] snapshot of [list]'s current
/// title/description/sections/items, for sending to
/// `ListGenerationService.modifyList` (see `AI_CONTRACT.md`'s
/// Modification Contract).
///
/// Completion state is deliberately never included: the AI never
/// decides persisted completion (see TASK-052 for how an accepted
/// modification's items get matched back to what should stay checked).
///
/// Mirrors `saveListAsTemplate`'s read pattern -- reading through the
/// repositories directly rather than requiring a combined read model,
/// since nothing else needs one at the domain layer.
Future<GeneratedList> buildListSnapshot({
  required ListRecord list,
  required SectionRepository sectionRepository,
  required ListItemRepository itemRepository,
}) async {
  final sections = await sectionRepository.getSections(list.id);
  final items = await itemRepository.getItems(list.id);

  final itemsBySection = <String, List<ListItemRecord>>{};
  for (final item in items) {
    itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
  }

  return GeneratedList(
    title: list.title,
    description: list.description,
    sections: [
      for (final section in sections)
        GeneratedSection(
          title: section.title,
          items: [
            for (final item in itemsBySection[section.id] ?? const [])
              GeneratedItem(text: item.content),
          ],
        ),
    ],
  );
}
