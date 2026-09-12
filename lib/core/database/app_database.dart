import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The application's local Drift/SQLite database.
///
/// Schema v1 defined [Lists], [Sections], and [ListItems]. Schema v2
/// added [Templates], [TemplateSections], and [TemplateItems] (TASK-030).
/// Any future schema change must bump [schemaVersion] and add a step
/// to [migration] per ARCHITECTURE.md.
@DriftDatabase(
  tables: [
    Lists,
    Sections,
    ListItems,
    Templates,
    TemplateSections,
    TemplateItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(templates);
        await m.createTable(templateSections);
        await m.createTable(templateItems);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'promptlist');
  }
}
