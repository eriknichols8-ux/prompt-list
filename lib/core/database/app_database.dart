import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The application's local Drift/SQLite database.
///
/// Tables are added starting with TASK-010 (database schema v1). This
/// class exists ahead of that so the Riverpod + Drift plumbing can be
/// verified independently of the domain schema.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'promptlist');
  }
}
