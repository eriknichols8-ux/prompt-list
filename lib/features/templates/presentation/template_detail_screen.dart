import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/features/lists/presentation/list_detail_screen.dart';
import 'package:promptlist/features/lists/presentation/list_providers.dart';
import 'package:promptlist/features/templates/domain/template_repository.dart';
import 'package:promptlist/features/templates/presentation/template_providers.dart';

/// Previews a template's structure and lets the user create an
/// independent list from it.
class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({required this.templateId, super.key});

  final String templateId;

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final withSections = await ref.read(templateProvider(templateId).future);
    if (withSections == null || !context.mounted) return;

    final newList = await ref
        .read(listRepositoryProvider)
        .createListFromTemplate(withSections);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListDetailScreen(listId: newList.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(templateProvider(templateId));

    return Scaffold(
      appBar: AppBar(
        title: template.when(
          data: (t) => Text(t?.template.name ?? 'Template'),
          loading: () => const Text('Template'),
          error: (_, _) => const Text('Template'),
        ),
      ),
      body: template.when(
        data: (withSections) {
          if (withSections == null) {
            return const Center(child: Text('This template no longer exists.'));
          }
          return _TemplatePreview(withSections: withSections);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load template: $error')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => _createList(context, ref),
            child: const Text('Create list'),
          ),
        ),
      ),
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.withSections});

  final TemplateWithSections withSections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = withSections.template;
    final sections = withSections.sections;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (template.description != null) ...[
          Text(template.description!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        for (final sectionWithItems in sections) ...[
          if (sectionWithItems.section.title != null) ...[
            Text(
              sectionWithItems.section.title!,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
          ],
          for (final item in sectionWithItems.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle_outlined,
                    size: 8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.content)),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
