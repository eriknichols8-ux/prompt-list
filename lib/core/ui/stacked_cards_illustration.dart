import 'package:flutter/material.dart';

/// Which empty state this illustration is standing in for -- each gets
/// a different accent mark on the front card.
enum StackedCardsVariant { checklist, templates }

/// A small hero illustration for empty states, built from the same
/// visual vocabulary as `PromptToListIcon` (rounded cards, simple line
/// marks in the app's own palette) rather than a generic centered
/// Material icon or an external image asset. Per CLAUDE.md's
/// "AI-Generated Visual Assets" section, illustrated empty states are
/// encouraged, but generating real artwork isn't available in this
/// environment; per docs/DESIGN_RALPH.md ("if image generation is
/// unavailable, do not block the loop... use a tasteful fallback"),
/// this is that fallback -- a bespoke vector illustration with zero
/// new asset/licensing surface, in the same style already established
/// for the AI-create icon.
class StackedCardsIllustration extends StatelessWidget {
  const StackedCardsIllustration({
    required this.variant,
    this.size = 96,
    super.key,
  });

  final StackedCardsVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _StackedCardsPainter(variant: variant, colorScheme: colorScheme),
    );
  }
}

class _StackedCardsPainter extends CustomPainter {
  const _StackedCardsPainter({
    required this.variant,
    required this.colorScheme,
  });

  final StackedCardsVariant variant;
  final ColorScheme colorScheme;

  RRect _cardRect(Offset center, double cardSize) {
    final rect = Rect.fromCenter(
      center: center,
      width: cardSize,
      height: cardSize * 0.78,
    );
    return RRect.fromRectAndRadius(rect, Radius.circular(cardSize * 0.16));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final cardSize = s * 0.6;

    void drawBackCard({
      required double rotation,
      required Offset offset,
      required Color color,
    }) {
      canvas.save();
      canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
      canvas.rotate(rotation);
      canvas.drawRRect(
        _cardRect(Offset.zero, cardSize),
        Paint()..color = color,
      );
      canvas.restore();
    }

    drawBackCard(
      rotation: -0.22,
      offset: const Offset(-7, -3),
      color: colorScheme.tertiaryContainer,
    );
    drawBackCard(
      rotation: 0.16,
      offset: const Offset(7, 3),
      color: colorScheme.surfaceContainerHigh,
    );

    // Front card, straight-on, carrying the accent marks.
    final frontCenter = Offset(center.dx, center.dy + s * 0.02);
    final frontRRect = _cardRect(frontCenter, cardSize);
    canvas.drawRRect(frontRRect, Paint()..color = colorScheme.primaryContainer);

    final markPaint = Paint()
      ..color = colorScheme.onPrimaryContainer
      ..strokeWidth = s * 0.026
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = frontRRect.outerRect;
    final left = rect.left + cardSize * 0.18;
    final right = rect.left + cardSize * 0.66;

    canvas.drawLine(
      Offset(left, rect.top + cardSize * 0.24),
      Offset(right, rect.top + cardSize * 0.24),
      markPaint,
    );
    canvas.drawLine(
      Offset(left, rect.top + cardSize * 0.38),
      Offset(rect.left + cardSize * 0.48, rect.top + cardSize * 0.38),
      markPaint,
    );

    switch (variant) {
      case StackedCardsVariant.checklist:
        final checkPath = Path()
          ..moveTo(left, rect.top + cardSize * 0.58)
          ..lineTo(left + cardSize * 0.07, rect.top + cardSize * 0.65)
          ..lineTo(left + cardSize * 0.20, rect.top + cardSize * 0.48);
        canvas.drawPath(checkPath, markPaint);
        canvas.drawLine(
          Offset(left + cardSize * 0.30, rect.top + cardSize * 0.58),
          Offset(right, rect.top + cardSize * 0.58),
          markPaint,
        );
      case StackedCardsVariant.templates:
        // Two small overlapping squares -- a "duplicate/reusable" mark,
        // kept well inside the card so it never fights the rounded
        // corners the way a corner fold would.
        final squareSize = cardSize * 0.17;
        final backSquare = Rect.fromLTWH(
          left,
          rect.top + cardSize * 0.50,
          squareSize,
          squareSize,
        );
        final frontSquare = Rect.fromLTWH(
          left + squareSize * 0.45,
          rect.top + cardSize * 0.50 + squareSize * 0.45,
          squareSize,
          squareSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            backSquare,
            Radius.circular(squareSize * 0.2),
          ),
          markPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            frontSquare,
            Radius.circular(squareSize * 0.2),
          ),
          Paint()..color = colorScheme.primaryContainer,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            frontSquare,
            Radius.circular(squareSize * 0.2),
          ),
          markPaint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _StackedCardsPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.colorScheme != colorScheme;
}
