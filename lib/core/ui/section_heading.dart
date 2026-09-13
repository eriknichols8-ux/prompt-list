import 'package:flutter/material.dart';

/// A small colored marker beside a section title within a list or
/// template. Section titles are user- (or template-) authored free
/// text, e.g. "Produce" or "Weekend Chores" --- unlike the all-caps
/// [AppEyebrowText] reserved for short, app-authored structural labels
/// ("Built-in", "Your request"), forcing a user's own casual section
/// name into uppercase would read as shouting. This gives section
/// titles the same "deliberate, colored, structural" visual language
/// established elsewhere in the app without changing their case.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
