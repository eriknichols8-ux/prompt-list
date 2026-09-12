import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/ui/confirm_dialog.dart';
import 'package:promptlist/features/ai_generation/domain/ai_generation_result.dart';
import 'package:promptlist/features/ai_generation/domain/generated_list.dart';
import 'package:promptlist/features/ai_generation/presentation/ai_generation_providers.dart';
import 'package:promptlist/features/ai_generation/presentation/generated_list_preview_screen.dart';
import 'package:promptlist/features/lists/domain/build_list_snapshot.dart';
import 'package:promptlist/features/lists/domain/section_repository.dart';
import 'package:promptlist/features/lists/presentation/ai_modify_list_dialog.dart';
import 'package:promptlist/features/lists/presentation/edit_item_dialog.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';
import 'package:promptlist/features/lists/presentation/move_to_section_dialog.dart';
import 'package:promptlist/features/lists/presentation/rename_list_dialog.dart';
import 'package:promptlist/features/lists/presentation/section_dialog.dart';
import 'package:promptlist/features/templates/domain/save_list_as_template.dart';
import 'package:promptlist/features/templates/presentation/save_as_template_dialog.dart';
import 'package:promptlist/features/templates/presentation/template_providers.dart';

enum _ListMenuAction {
  rename,
  addSection,
  aiModify,
  clearCompleted,
  saveAsTemplate,
  delete,
}

/// Shows a single list: its items, with add/edit/delete/complete and
/// drag-and-drop reordering, grouped into sections once a list has
/// more than one. A single-section list (the common case) renders
/// exactly as a flat checklist, with no section chrome at all --- see
/// PRODUCT_SPEC.md section 8: "A basic list should not require the
/// user to understand sections."
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

  Future<void> _addSection(BuildContext context, WidgetRef ref) async {
    final title = await showSectionDialog(context, dialogTitle: 'New section');
    if (title == null) return;
    await ref
        .read(sectionRepositoryProvider)
        .createSection(listId: listId, title: title);
  }

  Future<void> _askAiToModify(
    BuildContext context,
    WidgetRef ref,
    ListRecord record,
  ) async {
    final instruction = await showAiModifyListDialog(context);
    if (instruction == null || !context.mounted) return;

    final snapshot = await buildListSnapshot(
      list: record,
      sectionRepository: ref.read(sectionRepositoryProvider),
      itemRepository: ref.read(listItemRepositoryProvider),
    );
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Asking AI...'),
          ],
        ),
      ),
    );

    final service = ref.read(listGenerationServiceProvider);
    final result = await service.modifyList(
      snapshot: snapshot,
      instruction: instruction,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the loading dialog

    switch (result) {
      case AiGenerationSuccess(:final list):
        final accepted = await Navigator.of(context).push<GeneratedList>(
          MaterialPageRoute(
            builder: (_) => GeneratedListPreviewScreen(
              initial: list,
              title: 'Review AI changes',
              acceptLabel: (n) => 'Apply changes ($n item${n == 1 ? '' : 's'})',
            ),
          ),
        );
        if (!context.mounted || accepted == null) return;
        // TASK-052 applies `accepted` back into this list; for now,
        // acknowledge acceptance without changing anything yet.
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Changes accepted.')));
      case AiGenerationError(:final failure):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
    }
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

  Future<void> _saveAsTemplate(
    BuildContext context,
    WidgetRef ref,
    ListRecord record,
  ) async {
    final name = await showSaveAsTemplateDialog(
      context,
      initialName: record.title,
    );
    if (name == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await saveListAsTemplate(
      sectionRepository: ref.read(sectionRepositoryProvider),
      itemRepository: ref.read(listItemRepositoryProvider),
      templateRepository: ref.read(templateRepositoryProvider),
      listId: record.id,
      name: name,
    );
    messenger.showSnackBar(SnackBar(content: Text('Saved as "$name"')));
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
                      case _ListMenuAction.addSection:
                        _addSection(context, ref);
                      case _ListMenuAction.aiModify:
                        _askAiToModify(context, ref, record);
                      case _ListMenuAction.clearCompleted:
                        _clearCompleted(context, ref);
                      case _ListMenuAction.saveAsTemplate:
                        _saveAsTemplate(context, ref, record);
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
                      value: _ListMenuAction.addSection,
                      child: Text('Add section'),
                    ),
                    PopupMenuItem(
                      value: _ListMenuAction.aiModify,
                      child: Text('Ask AI to change this list'),
                    ),
                    PopupMenuItem(
                      value: _ListMenuAction.clearCompleted,
                      child: Text('Clear completed'),
                    ),
                    PopupMenuItem(
                      value: _ListMenuAction.saveAsTemplate,
                      child: Text('Save as template'),
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

class _ItemsBody extends ConsumerWidget {
  const _ItemsBody({required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(sectionsWithItemsProvider(listId));

    return grouped.when(
      data: (sections) {
        if (sections.length <= 1) {
          final only = sections.isEmpty ? null : sections.single;
          return _SimpleItemsView(
            sectionId: only?.section.id,
            items: only?.items ?? const [],
          );
        }
        return _SectionedItemsView(listId: listId, sections: sections);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load items: $error')),
    );
  }
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

/// The flat, header-less checklist used when a list has zero or one
/// section --- the common case. Behaves exactly like a plain checklist;
/// [sectionId] is null only when the list somehow has no section yet
/// (a transient state right after creation).
class _SimpleItemsView extends ConsumerStatefulWidget {
  const _SimpleItemsView({required this.sectionId, required this.items});

  final String? sectionId;
  final List<ListItemRecord> items;

  @override
  ConsumerState<_SimpleItemsView> createState() => _SimpleItemsViewState();
}

class _SimpleItemsViewState extends ConsumerState<_SimpleItemsView> {
  final _addController = TextEditingController();

  bool get _canAdd =>
      widget.sectionId != null && _addController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final sectionId = widget.sectionId;
    if (sectionId == null || !_canAdd) return;
    final text = _addController.text;
    _addController.clear();
    await ref
        .read(listItemRepositoryProvider)
        .addItemToSection(sectionId: sectionId, text: text);
  }

  Future<void> _reorder(int oldIndex, int newIndex) {
    final sectionId = widget.sectionId!;
    return ref
        .read(listItemRepositoryProvider)
        .reorderItem(
          sectionId: sectionId,
          oldIndex: oldIndex,
          newIndex: newIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: widget.items.isEmpty
              ? const _EmptyItemsState()
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  buildDefaultDragHandles: false,
                  itemCount: widget.items.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) => _ItemRow(
                    key: ValueKey(widget.items[index].id),
                    item: widget.items[index],
                    index: index,
                  ),
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

/// The grouped view used once a list has more than one section.
/// Sections reorder via up/down controls (rather than drag-and-drop,
/// which would require nesting two independently-draggable lists);
/// items still drag-and-drop to reorder within their own section.
class _SectionedItemsView extends ConsumerWidget {
  const _SectionedItemsView({required this.listId, required this.sections});

  final String listId;
  final List<SectionWithItems> sections;

  Future<void> _moveSection(WidgetRef ref, int index, int delta) {
    return ref
        .read(sectionRepositoryProvider)
        .reorderSection(
          listId: listId,
          oldIndex: index,
          newIndex: index + delta,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++)
            _SectionBlock(
              listId: listId,
              sectionWithItems: sections[i],
              otherSections: [
                for (final other in sections)
                  if (other.section.id != sections[i].section.id) other.section,
              ],
              canMoveUp: i > 0,
              canMoveDown: i < sections.length - 1,
              onMoveUp: () => _moveSection(ref, i, -1),
              onMoveDown: () => _moveSection(ref, i, 1),
            ),
        ],
      ),
    );
  }
}

class _SectionBlock extends ConsumerStatefulWidget {
  const _SectionBlock({
    required this.listId,
    required this.sectionWithItems,
    required this.otherSections,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String listId;
  final SectionWithItems sectionWithItems;
  final List<SectionRecord> otherSections;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  ConsumerState<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends ConsumerState<_SectionBlock> {
  final _addController = TextEditingController();

  SectionRecord get _section => widget.sectionWithItems.section;
  List<ListItemRecord> get _items => widget.sectionWithItems.items;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final newTitle = await showSectionDialog(
      context,
      dialogTitle: 'Rename section',
      initialTitle: _section.title ?? '',
    );
    if (newTitle == null) return;
    await ref
        .read(sectionRepositoryProvider)
        .renameSection(sectionId: _section.id, title: newTitle);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this section?',
      message: _items.isEmpty
          ? 'This section will be removed.'
          : 'This section and its ${_items.length} item(s) will be removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sectionRepositoryProvider).deleteSection(_section.id);
    } on SectionValidationException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addItem() async {
    final text = _addController.text;
    if (text.trim().isEmpty) return;
    _addController.clear();
    await ref
        .read(listItemRepositoryProvider)
        .addItemToSection(sectionId: _section.id, text: text);
  }

  Future<void> _reorder(int oldIndex, int newIndex) {
    return ref
        .read(listItemRepositoryProvider)
        .reorderItem(
          sectionId: _section.id,
          oldIndex: oldIndex,
          newIndex: newIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _rename,
                    child: Text(
                      _section.title ?? 'Untitled section',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: 18,
                  tooltip: 'Move section up',
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 18,
                  tooltip: 'Move section down',
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  tooltip: 'Delete section',
                  onPressed: _delete,
                ),
              ],
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) => _ItemRow(
              key: ValueKey(_items[index].id),
              item: _items[index],
              index: index,
              otherSections: widget.otherSections,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      hintText: 'Add an item',
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add item',
                  onPressed: _addItem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single item row: checkbox, text (tap to edit), and trailing
/// delete/move/drag-handle actions. Shared by both the simple and
/// sectioned views. [otherSections] is empty (hiding the move action)
/// in the simple view, since there is nowhere else to move an item to.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.index,
    this.otherSections = const [],
  });

  final ListItemRecord item;
  final int index;
  final List<SectionRecord> otherSections;

  Future<void> _editItem(BuildContext context, WidgetRef ref) async {
    final newText = await showEditItemDialog(
      context,
      initialText: item.content,
    );
    if (newText == null) return;
    await ref
        .read(listItemRepositoryProvider)
        .editItemText(itemId: item.id, text: newText);
  }

  Future<void> _deleteItem(WidgetRef ref) {
    return ref.read(listItemRepositoryProvider).deleteItem(item.id);
  }

  Future<void> _toggleCompleted(WidgetRef ref) {
    return ref
        .read(listItemRepositoryProvider)
        .setItemCompleted(itemId: item.id, completed: !item.completed);
  }

  Future<void> _moveToSection(BuildContext context, WidgetRef ref) async {
    final target = await showMoveToSectionDialog(
      context,
      sections: otherSections,
    );
    if (target == null) return;
    await ref
        .read(listItemRepositoryProvider)
        .moveItemToSection(itemId: item.id, targetSectionId: target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Checkbox(
        value: item.completed,
        onChanged: (_) => _toggleCompleted(ref),
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
      onTap: () => _editItem(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (otherSections.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              tooltip: 'Move to section',
              onPressed: () => _moveToSection(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete item',
            onPressed: () => _deleteItem(ref),
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
  }
}
