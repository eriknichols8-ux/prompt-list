import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/database/database_provider.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/data/drift_section_repository.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';

/// The app-wide [ListRepository] instance.
final listRepositoryProvider = Provider<ListRepository>((ref) {
  return DriftListRepository(ref.watch(appDatabaseProvider));
});

/// Reactive stream of saved lists with their completion progress, for
/// the Lists home screen.
final listSummariesProvider = StreamProvider<List<ListSummary>>((ref) {
  return ref.watch(listRepositoryProvider).watchListSummaries();
});

/// A single list by ID, for the list detail screen. Reactive so the
/// screen reflects renames and archive/unarchive without a manual
/// refresh.
final listByIdProvider = StreamProvider.family<ListRecord?, String>((ref, id) {
  return ref.watch(listRepositoryProvider).watchList(id);
});

/// The app-wide [ListItemRepository] instance.
final listItemRepositoryProvider = Provider<ListItemRepository>((ref) {
  return DriftListItemRepository(ref.watch(appDatabaseProvider));
});

/// Reactive stream of a list's items across all of its sections, for
/// the list detail screen.
final itemsProvider = StreamProvider.family<List<ListItemRecord>, String>((
  ref,
  listId,
) {
  return ref.watch(listItemRepositoryProvider).watchItems(listId);
});

/// The app-wide [SectionRepository] instance.
final sectionRepositoryProvider = Provider<SectionRepository>((ref) {
  return DriftSectionRepository(ref.watch(appDatabaseProvider));
});

/// Reactive stream of a list's sections, for the list detail screen.
final sectionsProvider = StreamProvider.family<List<SectionRecord>, String>((
  ref,
  listId,
) {
  return ref.watch(sectionRepositoryProvider).watchSections(listId);
});

/// A section paired with its items, in display order.
class SectionWithItems {
  const SectionWithItems({required this.section, required this.items});

  final SectionRecord section;
  final List<ListItemRecord> items;
}

/// Combines [sectionsProvider] and [itemsProvider] into a per-section
/// grouping, so the list detail screen can render one block per
/// section without a dedicated repository query.
final sectionsWithItemsProvider =
    Provider.family<AsyncValue<List<SectionWithItems>>, String>((ref, listId) {
      final sections = ref.watch(sectionsProvider(listId));
      final items = ref.watch(itemsProvider(listId));

      if (sections.isLoading || items.isLoading) {
        return const AsyncValue.loading();
      }
      if (sections.hasError) {
        return AsyncValue.error(sections.error!, sections.stackTrace!);
      }
      if (items.hasError) {
        return AsyncValue.error(items.error!, items.stackTrace!);
      }

      final itemsBySection = <String, List<ListItemRecord>>{};
      for (final item in items.value!) {
        itemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
      }

      return AsyncValue.data([
        for (final section in sections.value!)
          SectionWithItems(
            section: section,
            items: itemsBySection[section.id] ?? const [],
          ),
      ]);
    });
