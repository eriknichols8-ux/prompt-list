import 'package:drift/drift.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/lists/domain/list_repository.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';
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
    // A single query joining through sections/listItems so Drift's
    // table-dependency tracking re-emits this stream on item changes
    // (completion toggles included), not just list-row changes.
    final totalItems = _db.listItems.id.count();
    final completedItems = _db.listItems.id.count(
      filter: _db.listItems.completed.equals(true),
    );

    final query =
        _db.select(_db.lists).join([
            leftOuterJoin(
              _db.sections,
              _db.sections.listId.equalsExp(_db.lists.id),
            ),
            leftOuterJoin(
              _db.listItems,
              _db.listItems.sectionId.equalsExp(_db.sections.id),
            ),
          ])
          ..where(_db.lists.archivedAt.isNull())
          ..groupBy([_db.lists.id])
          ..orderBy([OrderingTerm.desc(_db.lists.updatedAt)])
          ..addColumns([totalItems, completedItems]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ListSummary(
              list: row.readTable(_db.lists),
              totalItems: row.read(totalItems) ?? 0,
              completedItems: row.read(completedItems) ?? 0,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<ListRecord?> getList(String id) {
    return (_db.select(
      _db.lists,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<ListSummary>> searchLists(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return watchListSummaries().first;
    }

    final titleMatches =
        await (_db.select(_db.lists)..where(
              (tbl) => tbl.archivedAt.isNull() & tbl.title.contains(trimmed),
            ))
            .map((list) => list.id)
            .get();

    final itemMatchRows = await (_db.select(_db.listItems).join([
      innerJoin(
        _db.sections,
        _db.sections.id.equalsExp(_db.listItems.sectionId),
      ),
    ])..where(_db.listItems.content.contains(trimmed))).get();

    final matchingIds = <String>{
      ...titleMatches,
      ...itemMatchRows.map((row) => row.readTable(_db.sections).listId),
    };
    if (matchingIds.isEmpty) return const [];

    final totalItems = _db.listItems.id.count();
    final completedItems = _db.listItems.id.count(
      filter: _db.listItems.completed.equals(true),
    );

    final rows =
        await (_db.select(_db.lists).join([
                leftOuterJoin(
                  _db.sections,
                  _db.sections.listId.equalsExp(_db.lists.id),
                ),
                leftOuterJoin(
                  _db.listItems,
                  _db.listItems.sectionId.equalsExp(_db.sections.id),
                ),
              ])
              ..where(
                _db.lists.archivedAt.isNull() & _db.lists.id.isIn(matchingIds),
              )
              ..groupBy([_db.lists.id])
              ..orderBy([OrderingTerm.desc(_db.lists.updatedAt)])
              ..addColumns([totalItems, completedItems]))
            .get();

    return rows
        .map(
          (row) => ListSummary(
            list: row.readTable(_db.lists),
            totalItems: row.read(totalItems) ?? 0,
            completedItems: row.read(completedItems) ?? 0,
          ),
        )
        .toList();
  }

  @override
  Stream<ListRecord?> watchList(String id) {
    return (_db.select(
      _db.lists,
    )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
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
  Future<ListRecord> createListFromTemplate(TemplateWithSections template) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final listId = _generateId();

      await _db
          .into(_db.lists)
          .insert(
            ListsCompanion.insert(
              id: listId,
              title: template.template.name,
              description: Value(template.template.description),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (template.sections.isEmpty) {
        // Every list needs at least one section (see createList); an
        // empty template still yields a normal, usable blank list.
        await _db
            .into(_db.sections)
            .insert(
              SectionsCompanion.insert(
                id: _generateId(),
                listId: listId,
                sortOrder: _defaultSectionSortOrder,
              ),
            );
      }

      var sectionSortOrder = 0;
      for (final sectionWithItems in template.sections) {
        sectionSortOrder += _defaultSectionSortOrder;
        final sectionId = _generateId();
        await _db
            .into(_db.sections)
            .insert(
              SectionsCompanion.insert(
                id: sectionId,
                listId: listId,
                title: Value(sectionWithItems.section.title),
                sortOrder: sectionSortOrder,
              ),
            );

        var itemSortOrder = 0;
        for (final item in sectionWithItems.items) {
          itemSortOrder += _defaultSectionSortOrder;
          await _db
              .into(_db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: _generateId(),
                  sectionId: sectionId,
                  content: item.content,
                  sortOrder: itemSortOrder,
                  createdAt: now,
                ),
              );
        }
      }

      return (await getList(listId))!;
    });
  }

  @override
  Future<ListRecord> createListFromGeneratedList(GeneratedList generated) {
    return _db.transaction(() async {
      final now = DateTime.now();
      final listId = _generateId();

      await _db
          .into(_db.lists)
          .insert(
            ListsCompanion.insert(
              id: listId,
              title: generated.title,
              description: Value(generated.description),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (generated.sections.isEmpty) {
        // Every list needs at least one section (see createList); the
        // preview screen already drops empty sections and disables
        // acceptance once every item is removed, but an empty generated
        // list should still yield a normal, usable blank list.
        await _db
            .into(_db.sections)
            .insert(
              SectionsCompanion.insert(
                id: _generateId(),
                listId: listId,
                sortOrder: _defaultSectionSortOrder,
              ),
            );
      }

      var sectionSortOrder = 0;
      for (final section in generated.sections) {
        sectionSortOrder += _defaultSectionSortOrder;
        final sectionId = _generateId();
        await _db
            .into(_db.sections)
            .insert(
              SectionsCompanion.insert(
                id: sectionId,
                listId: listId,
                title: Value(section.title),
                sortOrder: sectionSortOrder,
              ),
            );

        var itemSortOrder = 0;
        for (final item in section.items) {
          itemSortOrder += _defaultSectionSortOrder;
          await _db
              .into(_db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: _generateId(),
                  sectionId: sectionId,
                  content: item.text,
                  sortOrder: itemSortOrder,
                  createdAt: now,
                ),
              );
        }
      }

      return (await getList(listId))!;
    });
  }

  @override
  Future<ListRecord> applyGeneratedListModification({
    required String listId,
    required GeneratedList modified,
  }) {
    return _db.transaction(() async {
      final existingItems =
          await (_db.select(_db.listItems).join([
                innerJoin(
                  _db.sections,
                  _db.sections.id.equalsExp(_db.listItems.sectionId),
                ),
              ])..where(_db.sections.listId.equals(listId)))
              .map((row) => row.readTable(_db.listItems))
              .get();

      // Exact-text match, first-available: each existing item can only
      // preserve completion for one new item, so duplicate text never
      // double-preserves. See the matching strategy documented on
      // ListRepository.applyGeneratedListModification.
      final completionByText = <String, List<bool>>{};
      for (final item in existingItems) {
        completionByText
            .putIfAbsent(item.content.trim(), () => [])
            .add(item.completed);
      }
      bool wasCompleted(String text) {
        final queue = completionByText[text.trim()];
        if (queue == null || queue.isEmpty) return false;
        return queue.removeAt(0);
      }

      final now = DateTime.now();

      await (_db.delete(
        _db.sections,
      )..where((tbl) => tbl.listId.equals(listId))).go();

      await (_db.update(
        _db.lists,
      )..where((tbl) => tbl.id.equals(listId))).write(
        ListsCompanion(
          title: Value(modified.title),
          description: Value(modified.description),
          updatedAt: Value(now),
        ),
      );

      final sections = modified.sections.isEmpty
          ? const [GeneratedSection(items: [])]
          : modified.sections;

      var sectionSortOrder = 0;
      for (final section in sections) {
        sectionSortOrder += _defaultSectionSortOrder;
        final sectionId = _generateId();
        await _db
            .into(_db.sections)
            .insert(
              SectionsCompanion.insert(
                id: sectionId,
                listId: listId,
                title: Value(section.title),
                sortOrder: sectionSortOrder,
              ),
            );

        var itemSortOrder = 0;
        for (final item in section.items) {
          itemSortOrder += _defaultSectionSortOrder;
          final preserved = wasCompleted(item.text);
          await _db
              .into(_db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: _generateId(),
                  sectionId: sectionId,
                  content: item.text,
                  sortOrder: itemSortOrder,
                  createdAt: now,
                  completed: Value(preserved),
                  completedAt: Value(preserved ? now : null),
                ),
              );
        }
      }

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

  @override
  Future<void> archiveList(String id) async {
    await (_db.update(_db.lists)..where((tbl) => tbl.id.equals(id))).write(
      ListsCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> unarchiveList(String id) async {
    await (_db.update(_db.lists)..where((tbl) => tbl.id.equals(id))).write(
      const ListsCompanion(archivedAt: Value(null)),
    );
  }
}
