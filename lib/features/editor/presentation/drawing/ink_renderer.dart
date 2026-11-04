import 'dart:ui';

import '../../domain/stroke_point.dart';
import '../../domain/stroke_tool.dart';

/// Draws one stroke onto a canvas. Shared by the committed and live layers.
/// Width is constant from the first point to the last: pressure and speed
/// are ignored and the ends are not tapered.
abstract final class InkRenderer {
  static const double highlighterWidthScale = 6;
  static const double highlighterAlpha = 0.35;

  static void paintStroke(
    Canvas canvas, {
    required List<StrokePoint> points,
    required StrokeTool tool,
    required int colorValue,
    required double width,
  }) {
    if (points.isEmpty) return;

    final isHighlighter = tool == StrokeTool.highlighter;
    final strokeWidth = isHighlighter ? width * highlighterWidthScale : width;
    var color = Color(colorValue);
    if (isHighlighter) color = color.withValues(alpha: highlighterAlpha);

    if (points.length == 1) {
      final p = points.first;
      canvas.drawCircle(
        Offset(p.x, p.y),
        strokeWidth / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(_smoothPath(points), paint);
  }

  /// Quadratic curve through midpoints between samples.
  static Path _smoothPath(List<StrokePoint> pts) {
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    if (pts.length == 2) {
      path.lineTo(pts.last.x, pts.last.y);
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mx = (pts[i].x + pts[i + 1].x) / 2;
      final my = (pts[i].y + pts[i + 1].y) / 2;
      path.quadraticBezierTo(pts[i].x, pts[i].y, mx, my);
    }
    path.lineTo(pts.last.x, pts.last.y);
    return path;
  }
}
