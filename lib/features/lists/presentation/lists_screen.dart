import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

/// The Lists home screen: shows saved lists with their completion
/// progress, or a useful empty state when there are none.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(listSummariesProvider);

    return summaries.when(
      data: (lists) =>
          lists.isEmpty ? const _EmptyListsState() : _ListsView(lists: lists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load your lists: $error')),
    );
  }
}

class _EmptyListsState extends StatelessWidget {
  const _EmptyListsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No lists yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start from scratch, reuse a template, or describe what '
              'you need and let AI draft a list for you to review.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListsView extends StatelessWidget {
  const _ListsView({required this.lists});

  final List<ListSummary> lists;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ListCard(summary: lists[index]),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.summary});

  final ListSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = summary.totalItems == 0
        ? 0.0
        : summary.completedItems / summary.totalItems;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListDetailScreen(listId: summary.list.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.list.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary.totalItems == 0
                    ? 'No items yet'
                    : '${summary.completedItems}/${summary.totalItems} completed',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
