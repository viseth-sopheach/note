import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import 'ink_renderer.dart';

/// Lasso, selection box and the strokes being moved.
class SelectionLayer extends StatelessWidget {
  const SelectionLayer({super.key, required this.controller});

  final DrawingController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SelectionPainter(controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  SelectionPainter(this.controller)
      : super(repaint: Listenable.merge([controller, controller.live]));

  final DrawingController controller;

  static const Color _accent = Color(0xFF1E5AA8);

  @override
  void paint(Canvas canvas, Size size) {
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

    if (controller.isMovingSelection) {
      canvas.save();
      canvas.translate(controller.selectionDx, controller.selectionDy);
      for (final s in controller.selectedStrokes) {
        InkRenderer.paintStroke(
          canvas,
          points: s.points,
          tool: s.tool,
          colorValue: s.colorValue,
          width: s.width,
        );
      }
      canvas.restore();
    }

    final b = controller.selectionBounds;
    if (b == null) return;
    final rect = Rect.fromLTRB(b.left, b.top, b.right, b.bottom).inflate(6);
    canvas.drawRect(rect, Paint()..color = _accent.withValues(alpha: 0.06));
    canvas.drawRect(
      rect,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) =>
      oldDelegate.controller != controller;
}