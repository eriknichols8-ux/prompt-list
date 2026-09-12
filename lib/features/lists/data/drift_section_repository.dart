import 'package:drift/drift.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';
import 'package:uuid/uuid.dart';

/// Default gap between successive section sort-order values.
const _sortOrderStep = 1000;

/// Drift-backed implementation of [SectionRepository].
class DriftSectionRepository implements SectionRepository {
  DriftSectionRepository(this._db, {String Function()? idGenerator})
    : _generateId = idGenerator ?? const Uuid().v4;

  final AppDatabase _db;
  final String Function() _generateId;

  SimpleSelectStatement<$SectionsTable, SectionRecord> _orderedQuery(
    String listId,
  ) {
    return _db.select(_db.sections)
      ..where((tbl) => tbl.listId.equals(listId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]);
  }

  @override
  Stream<List<SectionRecord>> watchSections(String listId) {
    return _orderedQuery(listId).watch();
  }

  @override
  Future<List<SectionRecord>> getSections(String listId) {
    return _orderedQuery(listId).get();
  }

  @override
  Future<SectionRecord> createSection({
    required String listId,
    String? title,
  }) async {
    final trimmedTitle = title?.trim();

    return _db.transaction(() async {
      final existing = await _orderedQuery(listId).get();
      final nextSortOrder = existing.isEmpty
          ? _sortOrderStep
          : existing.last.sortOrder + _sortOrderStep;

      final sectionId = _generateId();
      await _db
          .into(_db.sections)
          .insert(
            SectionsCompanion.insert(
              id: sectionId,
              listId: listId,
              title: Value(
                (trimmedTitle == null || trimmedTitle.isEmpty)
                    ? null
                    : trimmedTitle,
              ),
              sortOrder: nextSortOrder,
            ),
          );

      return (_db.select(
        _db.sections,
      )..where((tbl) => tbl.id.equals(sectionId))).getSingle();
    });
  }

  @override
  Future<void> renameSection({required String sectionId, String? title}) async {
    final trimmedTitle = title?.trim();

    await (_db.update(
      _db.sections,
    )..where((tbl) => tbl.id.equals(sectionId))).write(
      SectionsCompanion(
        title: Value(
          (trimmedTitle == null || trimmedTitle.isEmpty) ? null : trimmedTitle,
        ),
      ),
    );
  }

  @override
  Future<void> deleteSection(String sectionId) async {
    await _db.transaction(() async {
      final section = await (_db.select(
        _db.sections,
      )..where((tbl) => tbl.id.equals(sectionId))).getSingle();

      final siblingCount =
          await (_db.selectOnly(_db.sections)
                ..where(_db.sections.listId.equals(section.listId))
                ..addColumns([_db.sections.id.count()]))
              .map((row) => row.read(_db.sections.id.count()) ?? 0)
              .getSingle();

      if (siblingCount <= 1) {
        throw const SectionValidationException(
          'Cannot delete the only section in a list.',
        );
      }

      await (_db.delete(
        _db.sections,
      )..where((tbl) => tbl.id.equals(sectionId))).go();
    });
  }

  @override
  Future<void> reorderSection({
    required String listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    await _db.transaction(() async {
      final sections = await _orderedQuery(listId).get();
      final moved = sections.removeAt(oldIndex);
      sections.insert(newIndex, moved);

      for (var i = 0; i < sections.length; i++) {
        await (_db.update(
          _db.sections,
        )..where((tbl) => tbl.id.equals(sections[i].id))).write(
          SectionsCompanion(sortOrder: Value((i + 1) * _sortOrderStep)),
        );
      }
    });
  }
}
