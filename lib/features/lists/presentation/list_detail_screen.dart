import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/presentation/edit_item_dialog.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';

/// Shows a single list: its items, with add/edit/delete/complete.
/// Ordering and sections are built out starting in TASK-016.
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
          return _ItemsBody(listId: listId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load list: $error')),
      ),
    );
  }
}

class _ItemsBody extends ConsumerStatefulWidget {
  const _ItemsBody({required this.listId});

  final String listId;

  @override
  ConsumerState<_ItemsBody> createState() => _ItemsBodyState();
}

class _ItemsBodyState extends ConsumerState<_ItemsBody> {
  final _addController = TextEditingController();

  bool get _canAdd => _addController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (!_canAdd) return;
    final text = _addController.text;
    _addController.clear();
    await ref
        .read(listItemRepositoryProvider)
        .addItem(listId: widget.listId, text: text);
  }

  Future<void> _editItem(ListItemRecord item) async {
    final newText = await showEditItemDialog(
      context,
      initialText: item.content,
    );
    if (newText == null) return;
    await ref
        .read(listItemRepositoryProvider)
        .editItemText(itemId: item.id, text: newText);
  }

  Future<void> _deleteItem(ListItemRecord item) {
    return ref.read(listItemRepositoryProvider).deleteItem(item.id);
  }

  Future<void> _toggleCompleted(ListItemRecord item) {
    return ref
        .read(listItemRepositoryProvider)
        .setItemCompleted(itemId: item.id, completed: !item.completed);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider(widget.listId));

    return Column(
      children: [
        Expanded(
          child: items.when(
            data: (items) => items.isEmpty
                ? const Center(child: Text('No items yet. Add one below.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final theme = Theme.of(context);
                      return ListTile(
                        leading: Checkbox(
                          value: item.completed,
                          onChanged: (_) => _toggleCompleted(item),
                        ),
                        title: Text(
                          item.content,
                          style: item.completed
                              ? theme.textTheme.bodyLarge?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : theme.textTheme.bodyLarge,
                        ),
                        onTap: () => _editItem(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete item',
                          onPressed: () => _deleteItem(item),
                        ),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load items: $error')),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      hintText: 'Add an item',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add item',
                  onPressed: _canAdd ? _addItem : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
