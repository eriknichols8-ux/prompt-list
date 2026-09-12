import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';

void main() {
  test('AppDatabase opens and closes on an in-memory connection', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 1);
    // Touching the executor forces the connection to actually open.
    await database.customSelect('SELECT 1').get();
  });
}
