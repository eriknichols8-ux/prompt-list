import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';

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

  /// Non-archived lists (with progress) whose title or any item's text
  /// contains [query] (case-insensitive for the English alphabet, per
  /// SQLite's default `LIKE` behavior), ordered like
  /// [watchListSummaries]. A blank [query] returns every non-archived
  /// list, matching [watchListSummaries]'s unfiltered result.
  ///
  /// One-shot rather than reactive: search is a transient interaction,
  /// not a persistent view, so re-running it per keystroke is simpler
  /// than keeping a filtered stream alive.
  Future<List<ListSummary>> searchLists(String query);

  /// Emits the list identified by [id] whenever it changes (including
  /// rename and archive/unarchive), or `null` if it does not exist.
  Stream<ListRecord?> watchList(String id);

  /// Creates a list with [title] and optional [description], along with
  /// a single default section so items can be added immediately.
  ///
  /// Throws [ListValidationException] if [title] is blank.
  Future<ListRecord> createList({required String title, String? description});

  /// Creates a new, independent list by copying [template]'s structure:
  /// title, description, sections, and items. Copied items always
  /// start unchecked --- templates never carry completion state to
  /// begin with (see `TemplateItems`) --- and everything gets fresh
  /// IDs, so later editing the new list can never mutate the source
  /// template. If [template] has no sections, the new list still gets
  /// one default section, matching [createList].
  Future<ListRecord> createListFromTemplate(TemplateWithSections template);

  /// Creates a new list from an accepted AI-generated preview: title,
  /// sections, and items, all with fresh IDs and completion unchecked.
  ///
  /// This is the only place AI-generated content becomes persisted data
  /// (see `AI_CONTRACT.md`) --- it runs atomically, so a failure partway
  /// through never leaves a partial list behind, and once created the
  /// list is a normal list like any other; nothing about its origin
  /// changes how it behaves afterward.
  Future<ListRecord> createListFromGeneratedList(GeneratedList generated);

  /// Applies an accepted AI modification: atomically replaces the list
  /// identified by [listId]'s title, description, sections, and items
  /// with [modified]'s content.
  ///
  /// Completion state is never taken from the AI. An item in [modified]
  /// keeps its existing completion only when its trimmed text exactly
  /// matches an existing item's trimmed text (each existing item can be
  /// matched at most once, so duplicate text doesn't double-preserve);
  /// every other item -- new, reworded, or an extra duplicate beyond
  /// what matched -- starts unchecked. See `AI_CONTRACT.md`'s
  /// "Completion State During Modification" section.
  ///
  /// Runs in a single transaction, so a failure partway through leaves
  /// the original list completely intact.
  Future<ListRecord> applyGeneratedListModification({
    required String listId,
    required GeneratedList modified,
  });

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
