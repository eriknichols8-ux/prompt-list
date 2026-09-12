import 'package:drift/drift.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/domain/list_item_repository.dart';
import 'package:uuid/uuid.dart';

/// Default gap between successive item sort-order values.
const _sortOrderStep = 1000;

/// Drift-backed implementation of [ListItemRepository].
class DriftListItemRepository implements ListItemRepository {
  DriftListItemRepository(this._db, {String Function()? idGenerator})
    : _generateId = idGenerator ?? const Uuid().v4;

  final AppDatabase _db;
  final String Function() _generateId;

  @override
  Stream<List<ListItemRecord>> watchItems(String listId) {
    final query =
        _db.select(_db.listItems).join([
            innerJoin(
              _db.sections,
              _db.sections.id.equalsExp(_db.listItems.sectionId),
            ),
          ])
          ..where(_db.sections.listId.equals(listId))
          ..orderBy([
            OrderingTerm.asc(_db.sections.sortOrder),
            OrderingTerm.asc(_db.listItems.sortOrder),
          ]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.listItems)).toList(),
    );
  }

  @override
  Future<ListItemRecord> addItem({
    required String listId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const ListItemValidationException('Item text cannot be blank.');
    }

    return _db.transaction(() async {
      final section = await (_db.select(
        _db.sections,
      )..where((tbl) => tbl.listId.equals(listId))).getSingle();

      final existingItems = await (_db.select(
        _db.listItems,
      )..where((tbl) => tbl.sectionId.equals(section.id))).get();
      final nextSortOrder = existingItems.isEmpty
          ? _sortOrderStep
          : existingItems
                    .map((item) => item.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                _sortOrderStep;

      final itemId = _generateId();
      await _db
          .into(_db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: itemId,
              sectionId: section.id,
              content: trimmedText,
              sortOrder: nextSortOrder,
              createdAt: DateTime.now(),
            ),
          );

      return (_db.select(
        _db.listItems,
      )..where((tbl) => tbl.id.equals(itemId))).getSingle();
    });
  }

  @override
  Future<void> editItemText({
    required String itemId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const ListItemValidationException('Item text cannot be blank.');
    }

    await (_db.update(_db.listItems)..where((tbl) => tbl.id.equals(itemId)))
        .write(ListItemsCompanion(content: Value(trimmedText)));
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await (_db.delete(
      _db.listItems,
    )..where((tbl) => tbl.id.equals(itemId))).go();
  }
}
