import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/lists/domain/list_summary.dart';
import 'package:promptlist/features/lists/presentation/create_list_dialog.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

/// The Lists home screen: shows saved lists with their completion
/// progress, or a useful empty state when there are none. A search
/// field filters by title or item text once there's enough data that
/// scanning the full list stops being the fastest way to find one.
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createList(BuildContext context) async {
    final created = await showCreateListDialog(context);
    if (created == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListDetailScreen(listId: created.id)),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final summaries = trimmedQuery.isEmpty
        ? ref.watch(listSummariesProvider)
        : ref.watch(searchListsProvider(trimmedQuery));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search lists and items',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: trimmedQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: summaries.when(
              data: (lists) {
                if (lists.isEmpty) {
                  return trimmedQuery.isEmpty
                      ? const _EmptyListsState()
                      : _NoSearchResultsState(query: trimmedQuery);
                }
                return _ListsView(lists: lists);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load your lists: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createList(context),
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No matches for "$query"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different word, or search for text inside an item.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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
