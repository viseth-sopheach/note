import 'package:flutter/widgets.dart';

import '../../../library/domain/paper_template.dart';
import 'paper_colors.dart';

/// Page size in logical document units (A4 at 96 dpi).
const Size kPageSize = Size(794, 1123);

/// Spacing between template lines or dots, in document units.
const double kPaperSpacing = 32;

/// Top margin so the first lined row is not flush with the edge.
const double kPaperMargin = 48;

class PaperPainter extends CustomPainter {
  const PaperPainter(this.template);

  final PaperTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = PaperColors.surface);

    final linePaint = Paint()
      ..color = PaperColors.line
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (template) {
      case PaperTemplate.blank:
        break;
      case PaperTemplate.lined:
        for (var y = kPaperMargin + kPaperSpacing;
            y < size.height;
            y += kPaperSpacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
      case PaperTemplate.grid:
        for (var y = kPaperSpacing; y < size.height; y += kPaperSpacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        for (var x = kPaperSpacing; x < size.width; x += kPaperSpacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
        }
      case PaperTemplate.dotted:
        final dotPaint = Paint()..color = PaperColors.line;
        for (var y = kPaperSpacing; y < size.height; y += kPaperSpacing) {
          for (var x = kPaperSpacing; x < size.width; x += kPaperSpacing) {
            canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) =>
      oldDelegate.template != template;
}