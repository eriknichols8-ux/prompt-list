import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// PromptList's standard tappable content surface: replaces the ad hoc
/// `Material` + `InkWell` pairing that used to be duplicated per screen,
/// so every card in the app shares the same signature shape, color, and
/// press feedback (see [AppShapes.card]).
class AppCard extends StatelessWidget {
  const AppCard({required this.onTap, required this.child, super.key});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: AppShapes.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.card,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
