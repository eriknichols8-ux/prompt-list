import 'package:promptlist/core/database/app_database.dart';

/// Thrown when a section operation would violate data integrity ---
/// currently, only deleting a list's last remaining section.
class SectionValidationException implements Exception {
  const SectionValidationException(this.message);

  final String message;

  @override
  String toString() => 'SectionValidationException: $message';
}

/// Provider-independent persistence contract for a list's sections.
///
/// Every list always has at least one section (created alongside the
/// list by `ListRepository.createList`), so items always have
/// somewhere to live; see ARCHITECTURE.md's "Default Section
/// Strategy".
abstract interface class SectionRepository {
  /// Emits the current sections of [listId], ordered for display.
  Stream<List<SectionRecord>> watchSections(String listId);

  /// Creates a section in [listId] with optional [title], appended
  /// after the list's existing sections.
  Future<SectionRecord> createSection({required String listId, String? title});

  /// Sets the section's display title. A blank or null [title] clears
  /// it back to an untitled section --- unlike list/item text, a
  /// section title is optional, so this never rejects blank input.
  Future<void> renameSection({required String sectionId, String? title});

  /// Deletes the section identified by [sectionId] and (via cascade)
  /// its items.
  ///
  /// Throws [SectionValidationException] if this is the only section
  /// left in its list, since every list must keep at least one section
  /// for items to belong to.
  Future<void> deleteSection(String sectionId);

  /// Moves the section at [oldIndex] (within [listId]'s current
  /// [watchSections] order) to [newIndex] in the resulting list, and
  /// persists the new order for every section in the list.
  ///
  /// Indexes use final-list-position semantics, matching
  /// `ListItemRepository.reorderItem` and Flutter's
  /// `ReorderableListView.onReorderItem`.
  Future<void> reorderSection({
    required String listId,
    required int oldIndex,
    required int newIndex,
  });
}
