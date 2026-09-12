import 'package:drift/drift.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';
import 'package:uuid/uuid.dart';

/// Gap between successive sort-order values for a template's sections
/// and items.
const _sortOrderStep = 1000;

/// Drift-backed implementation of [TemplateRepository].
class DriftTemplateRepository implements TemplateRepository {
  DriftTemplateRepository(this._db, {String Function()? idGenerator})
    : _generateId = idGenerator ?? const Uuid().v4;

  final AppDatabase _db;
  final String Function() _generateId;

  @override
  Stream<List<TemplateRecord>> watchTemplates() {
    final query = _db.select(_db.templates)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.isBuiltIn),
        (tbl) => OrderingTerm.asc(tbl.name),
      ]);
    return query.watch();
  }

  JoinedSelectStatement<HasResultSet, Object?> _templateQuery(
    String templateId,
  ) {
    return _db.select(_db.templates).join([
        leftOuterJoin(
          _db.templateSections,
          _db.templateSections.templateId.equalsExp(_db.templates.id),
        ),
        leftOuterJoin(
          _db.templateItems,
          _db.templateItems.sectionId.equalsExp(_db.templateSections.id),
        ),
      ])
      ..where(_db.templates.id.equals(templateId))
      ..orderBy([
        OrderingTerm.asc(_db.templateSections.sortOrder),
        OrderingTerm.asc(_db.templateItems.sortOrder),
      ]);
  }

  TemplateWithSections? _group(List<TypedResult> rows) {
    if (rows.isEmpty) return null;

    final template = rows.first.readTable(_db.templates);
    final sectionOrder = <String>[];
    final itemsBySection = <String, List<TemplateItemRecord>>{};
    final sectionById = <String, TemplateSectionRecord>{};

    for (final row in rows) {
      final section = row.readTableOrNull(_db.templateSections);
      if (section == null) continue;
      if (!sectionById.containsKey(section.id)) {
        sectionById[section.id] = section;
        sectionOrder.add(section.id);
        itemsBySection[section.id] = [];
      }
      final item = row.readTableOrNull(_db.templateItems);
      if (item != null) {
        itemsBySection[section.id]!.add(item);
      }
    }

    return TemplateWithSections(
      template: template,
      sections: [
        for (final id in sectionOrder)
          TemplateSectionWithItems(
            section: sectionById[id]!,
            items: itemsBySection[id]!,
          ),
      ],
    );
  }

  @override
  Stream<TemplateWithSections?> watchTemplate(String templateId) {
    return _templateQuery(templateId).watch().map(_group);
  }

  @override
  Future<TemplateWithSections?> getTemplate(String templateId) async {
    return _group(await _templateQuery(templateId).get());
  }

  @override
  Future<TemplateRecord> createTemplate({
    required String name,
    String? description,
    bool isBuiltIn = false,
    List<TemplateSectionInput> sections = const [],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const TemplateValidationException('Template name cannot be blank.');
    }
    final trimmedDescription = description?.trim();

    return _db.transaction(() async {
      final now = DateTime.now();
      final templateId = _generateId();

      await _db
          .into(_db.templates)
          .insert(
            TemplatesCompanion.insert(
              id: templateId,
              name: trimmedName,
              description: Value(
                (trimmedDescription == null || trimmedDescription.isEmpty)
                    ? null
                    : trimmedDescription,
              ),
              isBuiltIn: Value(isBuiltIn),
              createdAt: now,
              updatedAt: now,
            ),
          );

      var sectionSortOrder = 0;
      for (final sectionInput in sections) {
        sectionSortOrder += _sortOrderStep;
        final sectionId = _generateId();
        final trimmedTitle = sectionInput.title?.trim();
        await _db
            .into(_db.templateSections)
            .insert(
              TemplateSectionsCompanion.insert(
                id: sectionId,
                templateId: templateId,
                title: Value(
                  (trimmedTitle == null || trimmedTitle.isEmpty)
                      ? null
                      : trimmedTitle,
                ),
                sortOrder: sectionSortOrder,
              ),
            );

        var itemSortOrder = 0;
        for (final itemText in sectionInput.items) {
          itemSortOrder += _sortOrderStep;
          await _db
              .into(_db.templateItems)
              .insert(
                TemplateItemsCompanion.insert(
                  id: _generateId(),
                  sectionId: sectionId,
                  content: itemText.trim(),
                  sortOrder: itemSortOrder,
                ),
              );
        }
      }

      return (_db.select(
        _db.templates,
      )..where((tbl) => tbl.id.equals(templateId))).getSingle();
    });
  }

  Future<TemplateRecord> _requireEditable(String templateId) async {
    final template = await (_db.select(
      _db.templates,
    )..where((tbl) => tbl.id.equals(templateId))).getSingle();
    if (template.isBuiltIn) {
      throw const TemplateValidationException(
        'Built-in templates cannot be edited.',
      );
    }
    return template;
  }

  @override
  Future<void> renameTemplate({
    required String templateId,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const TemplateValidationException('Template name cannot be blank.');
    }
    await _requireEditable(templateId);

    await (_db.update(
      _db.templates,
    )..where((tbl) => tbl.id.equals(templateId))).write(
      TemplatesCompanion(
        name: Value(trimmedName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _requireEditable(templateId);

    await (_db.delete(
      _db.templates,
    )..where((tbl) => tbl.id.equals(templateId))).go();
  }
}
