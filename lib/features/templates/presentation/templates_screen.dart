import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:promptlist/app/theme.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/core/ui/app_card.dart';
import 'package:promptlist/core/ui/stacked_cards_illustration.dart';
import 'package:promptlist/features/templates/presentation/template_detail_screen.dart';
import 'package:promptlist/features/templates/presentation/template_providers.dart';

/// The Templates browsing screen: lets the user pick a built-in or
/// user template to preview and create a list from.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return templates.when(
      data: (templates) => templates.isEmpty
          ? const _EmptyTemplatesState()
          : _TemplatesList(templates: templates),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load templates: $error')),
    );
  }
}

class _EmptyTemplatesState extends StatelessWidget {
  const _EmptyTemplatesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StackedCardsIllustration(
              variant: StackedCardsVariant.templates,
            ),
            const SizedBox(height: 20),
            Text(
              'No templates yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Save one of your own lists as a template to reuse its '
              'structure later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList({required this.templates});

  final List<TemplateRecord> templates;

  @override
  Widget build(BuildContext context) {
    // watchTemplates() already orders built-ins first, then
    // alphabetically, so a stable partition preserves that order
    // within each group.
    final builtIns = templates.where((t) => t.isBuiltIn).toList();
    final userTemplates = templates.where((t) => !t.isBuiltIn).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (builtIns.isNotEmpty) ...[
          const AppEyebrowText('Built-in'),
          const SizedBox(height: 10),
          for (final template in builtIns) ...[
            _TemplateCard(template: template),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
        if (userTemplates.isNotEmpty) ...[
          const AppEyebrowText('My Templates'),
          const SizedBox(height: 10),
          for (final template in userTemplates) ...[
            _TemplateCard(template: template),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final TemplateRecord template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TemplateDetailScreen(templateId: template.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name, style: theme.textTheme.titleMedium),
          if (template.description != null) ...[
            const SizedBox(height: 4),
            Text(template.description!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
