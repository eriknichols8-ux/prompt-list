import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Provides the single shared [AppDatabase] instance for the app.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
