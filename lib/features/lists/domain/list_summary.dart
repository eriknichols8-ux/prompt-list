import 'package:promptlist/core/database/app_database.dart';

/// A list paired with its item completion progress, for display on the
/// Lists home screen.
class ListSummary {
  const ListSummary({
    required this.list,
    required this.totalItems,
    required this.completedItems,
  });

  final ListRecord list;
  final int totalItems;
  final int completedItems;
}
