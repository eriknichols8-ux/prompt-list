import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';

/// Thrown when list input fails validation before it would be persisted.
class ListValidationException implements Exception {
  const ListValidationException(this.message);

  final String message;

  @override
  String toString() => 'ListValidationException: $message';
}

/// Provider-independent persistence contract for saved checklists.
///
/// Presentation code depends on this interface, not on Drift directly,
/// so it stays testable without a database.
abstract interface class ListRepository {
  /// Emits the current non-archived lists whenever they change.
  Stream<List<ListRecord>> watchLists();

  /// Emits the current non-archived lists together with their item
  /// completion progress, for display on the Lists home screen.
  Stream<List<ListSummary>> watchListSummaries();

  Future<ListRecord?> getList(String id);

  /// Emits the list identified by [id] whenever it changes (including
  /// rename and archive/unarchive), or `null` if it does not exist.
  Stream<ListRecord?> watchList(String id);

  /// Creates a list with [title] and optional [description], along with
  /// a single default section so items can be added immediately.
  ///
  /// Throws [ListValidationException] if [title] is blank.
  Future<ListRecord> createList({required String title, String? description});

  /// Renames the list identified by [id] to [title].
  ///
  /// Throws [ListValidationException] if [title] is blank.
  Future<void> renameList({required String id, required String title});

  /// Deletes the list identified by [id] and (via cascade) its sections
  /// and items.
  Future<void> deleteList(String id);

  /// Soft-deletes the list identified by [id]: stamps `archivedAt` so
  /// it drops out of [watchLists]/[watchListSummaries] without
  /// destroying any data, so the user-facing "delete list" action can
  /// safely offer undo via [unarchiveList].
  Future<void> archiveList(String id);

  /// Reverses [archiveList], restoring the list to normal visibility.
  Future<void> unarchiveList(String id);
}
