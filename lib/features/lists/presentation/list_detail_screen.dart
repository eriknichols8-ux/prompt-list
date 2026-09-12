import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

/// Shows a single list. Item CRUD, completion, and ordering are built
/// out starting in TASK-014.
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listByIdProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: list.when(
          data: (record) => Text(record?.title ?? 'List'),
          loading: () => const Text('List'),
          error: (_, _) => const Text('List'),
        ),
      ),
      body: list.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('This list no longer exists.'));
          }
          return Center(child: Text(record.title));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load list: $error')),
      ),
    );
  }
}
