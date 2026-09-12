import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The application's local Drift/SQLite database.
///
/// Schema v1 defines [Lists], [Sections], and [ListItems]. Any future
/// schema change must bump [schemaVersion] and add a step to
/// [migration] per ARCHITECTURE.md.
@DriftDatabase(tables: [Lists, Sections, ListItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'promptlist');
  }
}
