import 'package:promptlist/core/database/app_database.dart';

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

  Future<ListRecord?> getList(String id);

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
}
