import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/database/database_provider.dart';

/// Wraps [child] in a [ProviderScope] backed by [database].
///
/// `appDatabaseProvider.overrideWithValue` bypasses the provider's own
/// `ref.onDispose(database.close)`, so the caller must create [database]
/// (e.g. `AppDatabase(NativeDatabase.memory())`) and close it in
/// `tearDown`/`addTearDown` itself. Without that, drift's internal
/// stream-cleanup timer outlives the disposed widget tree and trips
/// flutter_test's "no pending timers" assertion.
Widget wrapWithProviders(Widget child, {required AppDatabase database}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
    child: child,
  );
}

/// Like [testWidgets], but for widget trees built with [wrapWithProviders]
/// that watch a Drift `.watch()` stream (directly or via a Riverpod
/// `StreamProvider`).
///
/// Cancelling a Drift query stream schedules a zero-duration debounce
/// timer internally. Normally that timer only fires when the framework
/// tears down the tree between tests, which is too late for
/// flutter_test's "no pending timers" check and gets attributed to
/// whichever test happens to be running next. This unmounts the tree
/// and pumps once more inside the same test so the timer fires before
/// the check runs.
@isTest
void driftTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    // A plain pump() doesn't elapse the fake clock at all, so a
    // zero-duration Timer scheduled during the disposal above would
    // stay pending; elapse by a nonzero amount so it actually fires.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
