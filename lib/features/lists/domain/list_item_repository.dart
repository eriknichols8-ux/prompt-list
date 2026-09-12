import 'package:promptlist/core/database/app_database.dart';

/// Thrown when item input fails validation before it would be persisted.
class ListItemValidationException implements Exception {
  const ListItemValidationException(this.message);

  final String message;

  @override
  String toString() => 'ListItemValidationException: $message';
}

/// Provider-independent persistence contract for the items within a
/// list.
abstract interface class ListItemRepository {
  /// Emits the current items for [listId] across all of its sections,
  /// ordered by section then by item --- for display, and for
  /// deriving a per-section grouping alongside `SectionRepository`.
  Stream<List<ListItemRecord>> watchItems(String listId);

  /// Adds an item with [text] to [listId]'s first section (by sort
  /// order). Useful for the common single-section list, where the
  /// caller does not need to think about sections at all.
  ///
  /// Throws [ListItemValidationException] if [text] is blank.
  Future<ListItemRecord> addItem({
    required String listId,
    required String text,
  });

  /// Adds an item with [text] to a specific section.
  ///
  /// Throws [ListItemValidationException] if [text] is blank.
  Future<ListItemRecord> addItemToSection({
    required String sectionId,
    required String text,
  });

  /// Moves the item identified by [itemId] into [targetSectionId],
  /// appending it after that section's existing items.
  Future<void> moveItemToSection({
    required String itemId,
    required String targetSectionId,
  });

  /// Updates the text of the item identified by [itemId].
  ///
  /// Throws [ListItemValidationException] if [text] is blank.
  Future<void> editItemText({required String itemId, required String text});

  /// Sets the completion state of the item identified by [itemId],
  /// stamping or clearing its completion timestamp to match.
  Future<void> setItemCompleted({
    required String itemId,
    required bool completed,
  });

  /// Deletes the item identified by [itemId].
  Future<void> deleteItem(String itemId);

  /// Deletes every completed item in [listId].
  Future<void> clearCompleted(String listId);

  /// Moves the item at [oldIndex] (within [sectionId]'s current order)
  /// to [newIndex] in the resulting list, and persists the new order
  /// for every item in that section. Does not move items between
  /// sections --- use [moveItemToSection] for that.
  ///
  /// Indexes use final-list-position semantics: after the move, the
  /// item sits at [newIndex]. This matches Flutter's
  /// `ReorderableListView.onReorderItem` (not the deprecated
  /// `onReorder`, which reports a pre-removal `newIndex`).
  Future<void> reorderItem({
    required String sectionId,
    required int oldIndex,
    required int newIndex,
  });
}
