import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/app/app.dart';
import 'package:promptlist/core/database/app_database.dart';

import 'support/test_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  driftTestWidgets('PromptListApp renders the Lists home shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithProviders(const PromptListApp(), database: database),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Lists'), findsWidgets);
  });
}
