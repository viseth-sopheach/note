import 'package:flutter/widgets.dart';

import '../../application/drawing_controller.dart';
import 'ink_renderer.dart';

/// Finished strokes. Repaints only when a stroke is added or removed.
class CommittedInkLayer extends StatelessWidget {
  const CommittedInkLayer({super.key, required this.controller});

  final DrawingController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: CommittedInkPainter(controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// The stroke being drawn. Repaints on every accepted point, alone in its
/// own layer so the paper and finished strokes are not redrawn.
class LiveInkLayer extends StatelessWidget {
  const LiveInkLayer({super.key, required this.controller});

  final DrawingController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: LiveInkPainter(controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class CommittedInkPainter extends CustomPainter {
  CommittedInkPainter(this.controller) : super(repaint: controller);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in controller.strokes) {
      InkRenderer.paintStroke(
        canvas,
        points: s.points,
        tool: s.tool,
        colorValue: s.colorValue,
        width: s.width,
      );
    }
  }

  @override
  bool shouldRepaint(CommittedInkPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class LiveInkPainter extends CustomPainter {
  LiveInkPainter(this.controller) : super(repaint: controller.live);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    InkRenderer.paintStroke(
      canvas,
      points: controller.livePoints,
      tool: controller.tool,
      colorValue: controller.colorValue,
      width: controller.width,
    );
  }

  @override
  bool shouldRepaint(LiveInkPainter oldDelegate) =>
      oldDelegate.controller != controller;
}