import 'dart:ui';

import '../../domain/stroke_point.dart';
import '../../domain/stroke_tool.dart';

/// Draws one stroke. Every stroke is a monoline: a constant-width stroke
/// along the untouched recorded path, with round caps and round joins.
/// Highlighter is the same geometry at a wider width and lower opacity.
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
      canvas.drawCircle(
        Offset(points.first.x, points.first.y),
        strokeWidth / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      return;
    }

    canvas.drawPath(
      _smoothPath(points),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  /// Quadratic curve through midpoints between samples (shapes, highlighter).
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
