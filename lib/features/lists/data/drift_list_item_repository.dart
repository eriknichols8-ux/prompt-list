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

  List<Join<HasResultSet, dynamic>> _sectionJoin() => [
    innerJoin(_db.sections, _db.sections.id.equalsExp(_db.listItems.sectionId)),
  ];

  @override
  Stream<List<ListItemRecord>> watchItems(String listId) {
    final query = _db.select(_db.listItems).join(_sectionJoin())
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
  Future<List<ListItemRecord>> getItems(String listId) async {
    final query = _db.select(_db.listItems).join(_sectionJoin())
      ..where(_db.sections.listId.equals(listId))
      ..orderBy([
        OrderingTerm.asc(_db.sections.sortOrder),
        OrderingTerm.asc(_db.listItems.sortOrder),
      ]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.listItems)).toList();
  }

  @override
  Future<ListItemRecord> addItem({
    required String listId,
    required String text,
  }) async {
    return _db.transaction(() async {
      final firstSection =
          await (_db.select(_db.sections)
                ..where((tbl) => tbl.listId.equals(listId))
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)])
                ..limit(1))
              .getSingle();
      return _insertItem(sectionId: firstSection.id, text: text);
    });
  }

  @override
  Future<ListItemRecord> addItemToSection({
    required String sectionId,
    required String text,
  }) {
    return _insertItem(sectionId: sectionId, text: text);
  }

  Future<ListItemRecord> _insertItem({
    required String sectionId,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const ListItemValidationException('Item text cannot be blank.');
    }

    return _db.transaction(() async {
      final existingItems = await (_db.select(
        _db.listItems,
      )..where((tbl) => tbl.sectionId.equals(sectionId))).get();
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
              sectionId: sectionId,
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
  Future<void> moveItemToSection({
    required String itemId,
    required String targetSectionId,
  }) async {
    await _db.transaction(() async {
      final existingItems = await (_db.select(
        _db.listItems,
      )..where((tbl) => tbl.sectionId.equals(targetSectionId))).get();
      final nextSortOrder = existingItems.isEmpty
          ? _sortOrderStep
          : existingItems
                    .map((item) => item.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                _sortOrderStep;

      await (_db.update(
        _db.listItems,
      )..where((tbl) => tbl.id.equals(itemId))).write(
        ListItemsCompanion(
          sectionId: Value(targetSectionId),
          sortOrder: Value(nextSortOrder),
        ),
      );
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
  Future<void> setItemCompleted({
    required String itemId,
    required bool completed,
  }) async {
    await (_db.update(
      _db.listItems,
    )..where((tbl) => tbl.id.equals(itemId))).write(
      ListItemsCompanion(
        completed: Value(completed),
        completedAt: Value(completed ? DateTime.now() : null),
      ),
    );
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await (_db.delete(
      _db.listItems,
    )..where((tbl) => tbl.id.equals(itemId))).go();
  }

  @override
  Future<void> clearCompleted(String listId) async {
    final sections = await (_db.select(
      _db.sections,
    )..where((tbl) => tbl.listId.equals(listId))).get();
    final sectionIds = sections.map((section) => section.id).toList();
    if (sectionIds.isEmpty) return;

    await (_db.delete(_db.listItems)..where(
          (tbl) => tbl.completed.equals(true) & tbl.sectionId.isIn(sectionIds),
        ))
        .go();
  }

  @override
  Future<void> reorderItem({
    required String sectionId,
    required int oldIndex,
    required int newIndex,
  }) async {
    await _db.transaction(() async {
      final items =
          await (_db.select(_db.listItems)
                ..where((tbl) => tbl.sectionId.equals(sectionId))
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
              .get();
      final moved = items.removeAt(oldIndex);
      items.insert(newIndex, moved);

      for (var i = 0; i < items.length; i++) {
        await (_db.update(
          _db.listItems,
        )..where((tbl) => tbl.id.equals(items[i].id))).write(
          ListItemsCompanion(sortOrder: Value((i + 1) * _sortOrderStep)),
        );
      }
    });
  }
}
