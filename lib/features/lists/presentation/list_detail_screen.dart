import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/ui/confirm_dialog.dart';
import 'package:promptlist/features/lists/presentation/edit_item_dialog.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';
import 'package:promptlist/features/lists/presentation/rename_list_dialog.dart';

enum _ListMenuAction { rename, clearCompleted, delete }

/// Shows a single list: its items, with add/edit/delete/complete and
/// drag-and-drop reordering. Sections are built out starting in
/// Milestone 2.
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({required this.listId, super.key});

  final String listId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ListRecord record,
  ) async {
    final newTitle = await showRenameListDialog(
      context,
      initialTitle: record.title,
    );
    if (newTitle == null) return;
    await ref
        .read(listRepositoryProvider)
        .renameList(id: record.id, title: newTitle);
  }

  Future<void> _clearCompleted(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear completed items?',
      message: 'Completed items in this list will be removed.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await ref.read(listItemRepositoryProvider).clearCompleted(listId);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ListRecord record,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this list?',
      message: '"${record.title}" and its items will be deleted.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Capture the repository itself, not `ref`: by the time the user
    // taps "Undo" this widget has been popped and disposed, so using
    // the (now-invalid) `ref` in the callback would throw.
    final listRepository = ref.read(listRepositoryProvider);
    await listRepository.archiveList(record.id);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${record.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => listRepository.unarchiveList(record.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listByIdProvider(listId));
    final record = list.value;

    return Scaffold(
      appBar: AppBar(
        title: list.when(
          data: (record) => Text(record?.title ?? 'List'),
          loading: () => const Text('List'),
          error: (_, _) => const Text('List'),
        ),
        actions: record == null
            ? null
            : [
                PopupMenuButton<_ListMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _ListMenuAction.rename:
                        _rename(context, ref, record);
                      case _ListMenuAction.clearCompleted:
                        _clearCompleted(context, ref);
                      case _ListMenuAction.delete:
                        _delete(context, ref, record);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ListMenuAction.rename,
                      child: Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: _ListMenuAction.clearCompleted,
                      child: Text('Clear completed'),
                    ),
                    PopupMenuItem(
                      value: _ListMenuAction.delete,
                      child: Text('Delete list'),
                    ),
                  ],
                ),
              ],
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

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_check_circle_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text('No items yet. Add one below.'),
          ],
        ),
      ),
    );
  }
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

  Future<void> _reorder(int oldIndex, int newIndex) {
    return ref
        .read(listItemRepositoryProvider)
        .reorderItem(
          listId: widget.listId,
          oldIndex: oldIndex,
          newIndex: newIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider(widget.listId));

    return Column(
      children: [
        Expanded(
          child: items.when(
            data: (items) => items.isEmpty
                ? const _EmptyItemsState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorderItem: _reorder,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final theme = Theme.of(context);
                      return ListTile(
                        key: ValueKey(item.id),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete item',
                              onPressed: () => _deleteItem(item),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
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
