import 'package:drift/drift.dart';
import 'package:promptlist/core/database/tables.dart';

part 'v1_database.g.dart';

/// A minimal Drift database reproducing PromptList's schema exactly as
/// it stood at v1 (TASK-010): only [Lists], [Sections], and
/// [ListItems], with no template tables. Used solely to build a v1
/// fixture file for `app_database_migration_test.dart` to migrate
/// forward from --- production code always uses [AppDatabase].
@DriftDatabase(tables: [Lists, Sections, ListItems])
class V1Database extends _$V1Database {
  V1Database(super.executor);

  @override
  int get schemaVersion => 1;
}
