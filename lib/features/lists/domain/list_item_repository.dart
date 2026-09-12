import 'package:promptlist/core/database/app_database.dart';

/// Thrown when item input fails validation before it would be persisted.
class ListItemValidationException implements Exception {
  const ListItemValidationException(this.message);

  final String message;

  @override
  String toString() => 'ListItemValidationException: $message';
}

/// Provider-independent persistence contract for the items within a
/// list. Items belong to sections, but sections are not yet
/// user-facing (Milestone 2), so this operates in terms of the list's
/// items directly; the default section created alongside the list
/// (see `ListRepository.createList`) is resolved internally.
abstract interface class ListItemRepository {
  /// Emits the current items for [listId], ordered for display.
  Stream<List<ListItemRecord>> watchItems(String listId);

  /// Adds an item with [text] to the list's default section.
  ///
  /// Throws [ListItemValidationException] if [text] is blank.
  Future<ListItemRecord> addItem({
    required String listId,
    required String text,
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

  /// Moves the item at [oldIndex] (within [listId]'s current
  /// [watchItems] order) to [newIndex] in the resulting list, and
  /// persists the new order for every item in the list.
  ///
  /// Indexes use final-list-position semantics: after the move, the
  /// item sits at [newIndex]. This matches Flutter's
  /// `ReorderableListView.onReorderItem` (not the deprecated
  /// `onReorder`, which reports a pre-removal `newIndex`).
  Future<void> reorderItem({
    required String listId,
    required int oldIndex,
    required int newIndex,
  });
}
