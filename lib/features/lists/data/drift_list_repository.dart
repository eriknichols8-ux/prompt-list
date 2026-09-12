import 'package:drift/drift.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:uuid/uuid.dart';

/// Default sort order assigned to a list's initial default section.
const _defaultSectionSortOrder = 1000;

/// Drift-backed implementation of [ListRepository].
class DriftListRepository implements ListRepository {
  DriftListRepository(this._db, {String Function()? idGenerator})
    : _generateId = idGenerator ?? const Uuid().v4;

  final AppDatabase _db;
  final String Function() _generateId;

  @override
  Stream<List<ListRecord>> watchLists() {
    final query = _db.select(_db.lists)
      ..where((tbl) => tbl.archivedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    return query.watch();
  }

  @override
  Stream<List<ListSummary>> watchListSummaries() {
    return watchLists().asyncMap((lists) async {
      final summaries = <ListSummary>[];
      for (final list in lists) {
        final total = await _countItems(list.id);
        final completed = await _countItems(list.id, completedOnly: true);
        summaries.add(
          ListSummary(list: list, totalItems: total, completedItems: completed),
        );
      }
      return summaries;
    });
  }

  Future<int> _countItems(String listId, {bool completedOnly = false}) async {
    final countExpression = _db.listItems.id.count();
    final query = _db.selectOnly(_db.listItems)
      ..join([
        innerJoin(
          _db.sections,
          _db.sections.id.equalsExp(_db.listItems.sectionId),
        ),
      ])
      ..where(_db.sections.listId.equals(listId))
      ..addColumns([countExpression]);
    if (completedOnly) {
      query.where(_db.listItems.completed.equals(true));
    }
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Future<ListRecord?> getList(String id) {
    return (_db.select(
      _db.lists,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<ListRecord> createList({
    required String title,
    String? description,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ListValidationException('List title cannot be blank.');
    }
    final trimmedDescription = description?.trim();

    return _db.transaction(() async {
      final now = DateTime.now();
      final listId = _generateId();

      await _db
          .into(_db.lists)
          .insert(
            ListsCompanion.insert(
              id: listId,
              title: trimmedTitle,
              description: Value(
                (trimmedDescription == null || trimmedDescription.isEmpty)
                    ? null
                    : trimmedDescription,
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db
          .into(_db.sections)
          .insert(
            SectionsCompanion.insert(
              id: _generateId(),
              listId: listId,
              sortOrder: _defaultSectionSortOrder,
            ),
          );

      return (await getList(listId))!;
    });
  }

  @override
  Future<void> renameList({required String id, required String title}) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ListValidationException('List title cannot be blank.');
    }

    await (_db.update(_db.lists)..where((tbl) => tbl.id.equals(id))).write(
      ListsCompanion(
        title: Value(trimmedTitle),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteList(String id) async {
    await (_db.delete(_db.lists)..where((tbl) => tbl.id.equals(id))).go();
  }
}
