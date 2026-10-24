import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import '../paper/paper_colors.dart';
import 'ink_renderer.dart';

/// Lasso, selection box and the strokes being moved.
class SelectionLayer extends StatelessWidget {
  const SelectionLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
    this.darkPaper = false,
  });

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SelectionPainter(controller, origin, darkPaper),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  SelectionPainter(
    this.controller, [
    this.origin = Offset.zero,
    this.darkPaper = false,
  ]) : super(repaint: Listenable.merge([controller, controller.live]));

  final DrawingController controller;
  final Offset origin;
  final bool darkPaper;

  static const Color _accent = Color(0xFF0A84FF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    _paintContent(canvas);
    canvas.restore();
  }

  void _paintContent(Canvas canvas) {
    final lasso = controller.lasso;
    if (lasso.length > 1) {
      final path = Path()..moveTo(lasso.first.x, lasso.first.y);
      for (final v in lasso.skip(1)) {
        path.lineTo(v.x, v.y);
      }
      canvas.drawPath(
        Path.from(path)..close(),
        Paint()..color = _accent.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = true,
      );
    }

    if (!controller.hasSelection) return;

    if (controller.isTransformingSelection) {
      canvas.save();
      canvas.translate(controller.selectionDx, controller.selectionDy);
      for (final s in controller.selectedStrokes) {
        InkRenderer.paintStroke(
          canvas,
          points: controller.previewPoints(s),
          tool: s.tool,
          colorValue: PaperColors.inkFor(s.colorValue, darkPaper: darkPaper),
          width: s.width,
        );
      }
      canvas.restore();
    }

    final f = controller.selectionFrame;
    if (f == null) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(f.left, f.top, f.right, f.bottom)
          .inflate(DrawingController.framePad),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = _accent.withValues(alpha: 0.08));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Handles keep a constant size on screen at any zoom.
    final k = 1 / (controller.viewScale?.call() ?? 1.0).clamp(0.05, 20.0);
    for (final spot in controller.handleSpots) {
      final c = Offset(spot.x, spot.y);
      canvas.drawCircle(c, 7 * k, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
        c,
        7 * k,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.origin != origin ||
      oldDelegate.darkPaper != darkPaper;
}