import 'package:flutter/material.dart';

/// PromptList's icon for the AI-create surface: a small card split into a
/// few typed lines above and one checked result line below, reading as
/// "your words become a checklist item" instead of reaching for a
/// sparkle -- CLAUDE.md's Visual Design Direction specifically warns
/// against sparkles standing in for the entire AI identity. Used for
/// both the "AI Create" navigation destination and the generation
/// button, so the same motif represents the feature everywhere it
/// appears.
class PromptToListIcon extends StatelessWidget {
  const PromptToListIcon({
    this.filled = false,
    this.size,
    this.color,
    super.key,
  });

  /// Bolder strokes and a faint card fill, mirroring how the other
  /// navigation destinations swap an outlined icon for a filled one
  /// when selected.
  final bool filled;

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color ?? const Color(0xFF000000);
    return CustomPaint(
      size: Size.square(resolvedSize),
      painter: _PromptToListPainter(color: resolvedColor, filled: filled),
    );
  }
}

class _PromptToListPainter extends CustomPainter {
  const _PromptToListPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cardRect = Rect.fromLTWH(s * 0.08, s * 0.12, s * 0.84, s * 0.76);
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(s * 0.12),
    );

    if (filled) {
      final fillPaint = Paint()..color = color.withValues(alpha: 0.16);
      canvas.drawRRect(cardRRect, fillPaint);
    }

    final strokeWidth = s * (filled ? 0.09 : 0.075);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(cardRRect, linePaint);

    // Two short "typed prompt" lines near the top of the card.
    canvas.drawLine(
      Offset(s * 0.22, s * 0.34),
      Offset(s * 0.78, s * 0.34),
      linePaint,
    );
    canvas.drawLine(
      Offset(s * 0.22, s * 0.46),
      Offset(s * 0.60, s * 0.46),
      linePaint,
    );

    // A full-width divider separating "typed" from "result".
    canvas.drawLine(
      Offset(cardRect.left, s * 0.58),
      Offset(cardRect.right, s * 0.58),
      linePaint,
    );

    // A small checkmark plus one line: the resulting checklist item.
    final checkPath = Path()
      ..moveTo(s * 0.20, s * 0.735)
      ..lineTo(s * 0.28, s * 0.80)
      ..lineTo(s * 0.40, s * 0.665);
    canvas.drawPath(checkPath, linePaint);
    canvas.drawLine(
      Offset(s * 0.48, s * 0.73),
      Offset(s * 0.78, s * 0.73),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PromptToListPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}
