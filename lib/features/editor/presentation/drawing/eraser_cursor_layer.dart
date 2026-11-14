import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';

/// Circle that matches the eraser size and follows the pointer.
class EraserCursorLayer extends StatelessWidget {
  const EraserCursorLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
  });

  final DrawingController controller;
  final Offset origin;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EraserCursorPainter(controller, origin),
      ),
    ),
  );
}

class _EraserCursorPainter extends CustomPainter {
  _EraserCursorPainter(this.c, this.origin) : super(repaint: c.live);

  final DrawingController c;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final p = c.eraserCursor;
    if (p == null) return;
    final k = 1 / (c.viewScale?.call() ?? 1.0).clamp(0.05, 20.0).toDouble();
    final center = origin + Offset(p.x, p.y);
    final r = c.eraserRadius;
    canvas.drawCircle(center, r, Paint()..color = const Color(0x1A808080));
    canvas.drawCircle(
      center, r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * k
        ..color = const Color(0xE6FFFFFF)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      center, r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * k
        ..color = const Color(0xCC000000)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_EraserCursorPainter old) =>
      old.c != c || old.origin != origin;
}