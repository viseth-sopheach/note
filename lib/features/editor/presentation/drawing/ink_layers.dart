import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import 'ink_renderer.dart';

/// Finished strokes. Repaints only when strokes or the selection change.
/// [origin] is the paper corner inside this layer.
class CommittedInkLayer extends StatelessWidget {
  const CommittedInkLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
  });

  final DrawingController controller;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: CommittedInkPainter(controller, origin),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// The stroke being drawn. Repaints on every accepted point, alone in its
/// own layer so the paper and finished strokes are not redrawn.
class LiveInkLayer extends StatelessWidget {
  const LiveInkLayer({
    super.key,
    required this.controller,
    this.origin = Offset.zero,
  });

  final DrawingController controller;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: LiveInkPainter(controller, origin),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class CommittedInkPainter extends CustomPainter {
  CommittedInkPainter(this.controller, [this.origin = Offset.zero])
      : super(repaint: controller);

  final DrawingController controller;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    final moving = controller.isMovingSelection;
    final selected = controller.selectedIds;
    for (final s in controller.strokes) {
      if (moving && selected.contains(s.id)) continue;
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

  @override
  bool shouldRepaint(CommittedInkPainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.origin != origin;
}

class LiveInkPainter extends CustomPainter {
  LiveInkPainter(this.controller, [this.origin = Offset.zero])
      : super(repaint: controller.live);

  final DrawingController controller;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    InkRenderer.paintStroke(
      canvas,
      points: controller.livePoints,
      tool: controller.tool,
      colorValue: controller.colorValue,
      width: controller.width,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiveInkPainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.origin != origin;
}