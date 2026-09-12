import 'package:flutter/material.dart';

import '../domain/generated_list.dart';

/// Reviews an AI-generated list before it becomes a real list.
///
/// Nothing here touches the database: this screen only lets the user
/// edit the title and remove unwanted items, then hands the edited
/// [GeneratedList] back to its caller via [Navigator.pop]. Popping with
/// `null` (via Cancel or the back button) discards the generated data
/// entirely. Turning an accepted result into persisted list/section/item
/// rows is handled by the caller (TASK-044).
class GeneratedListPreviewScreen extends StatefulWidget {
  const GeneratedListPreviewScreen({super.key, required this.initial});

  final GeneratedList initial;

  @override
  State<GeneratedListPreviewScreen> createState() =>
      _GeneratedListPreviewScreenState();
}

class _GeneratedListPreviewScreenState
    extends State<GeneratedListPreviewScreen> {
  late final TextEditingController _titleController;
  late final List<_PreviewSection> _sections;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _sections = widget.initial.sections
        .map(
          (section) => _PreviewSection(
            title: section.title,
            items: section.items.map((item) => item.text).toList(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _totalItems =>
      _sections.fold<int>(0, (sum, section) => sum + section.items.length);

  void _removeItem(int sectionIndex, int itemIndex) {
    setState(() => _sections[sectionIndex].items.removeAt(itemIndex));
  }

  void _cancel() => Navigator.of(context).pop();

  void _accept() {
    final title = _titleController.text.trim();
    final sections = _sections
        .where((section) => section.items.isNotEmpty)
        .map(
          (section) => GeneratedSection(
            title: section.title,
            items: section.items
                .map((text) => GeneratedItem(text: text))
                .toList(),
          ),
        )
        .toList();

    Navigator.of(context).pop(
      GeneratedList(
        title: title.isEmpty ? widget.initial.title : title,
        description: widget.initial.description,
        sections: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _totalItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review generated list'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: _cancel,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          for (var s = 0; s < _sections.length; s++) ...[
            if (_sections[s].title != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _sections[s].title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            for (var i = 0; i < _sections[s].items.length; i++)
              ListTile(
                title: Text(_sections[s].items[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove',
                  onPressed: () => _removeItem(s, i),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: totalItems > 0 ? _accept : null,
          child: Text(
            'Add to my lists ($totalItems item${totalItems == 1 ? '' : 's'})',
          ),
        ),
      ),
    );
  }
}

class _PreviewSection {
  _PreviewSection({required this.title, required this.items});

  final String? title;
  final List<String> items;
}
