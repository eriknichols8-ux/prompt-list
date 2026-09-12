import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/app/app.dart';

void main() {
  testWidgets('PromptListApp renders a Material app shell', (tester) async {
    await tester.pumpWidget(const PromptListApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PromptList'), findsOneWidget);
  });
}
