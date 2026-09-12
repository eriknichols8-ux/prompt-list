import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/database/database_provider.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';

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

/// Reactive stream of a list's items, for the list detail screen.
final itemsProvider = StreamProvider.family<List<ListItemRecord>, String>((
  ref,
  listId,
) {
  return ref.watch(listItemRepositoryProvider).watchItems(listId);
});
