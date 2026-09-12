import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/database/database_provider.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
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

/// A single list by ID, for the list detail screen.
final listByIdProvider = FutureProvider.family<ListRecord?, String>((ref, id) {
  return ref.watch(listRepositoryProvider).getList(id);
});
