import 'dart:ui';

import '../../domain/stroke_point.dart';
import '../../domain/stroke_tool.dart';

/// Draws one stroke onto a canvas. Shared by the committed and live layers.
abstract final class InkRenderer {
  static const double highlighterWidthScale = 6;
  static const double highlighterAlpha = 0.35;
  static const double _minPressureFactor = 0.4;

  static void paintStroke(
    Canvas canvas, {
    required List<StrokePoint> points,
    required StrokeTool tool,
    required int colorValue,
    required double width,
  }) {
    if (points.isEmpty) return;

    final isHighlighter = tool == StrokeTool.highlighter;
    final baseWidth = isHighlighter ? width * highlighterWidthScale : width;
    var color = Color(colorValue);
    if (isHighlighter) color = color.withValues(alpha: highlighterAlpha);

    if (points.length == 1) {
      final p = points.first;
      canvas.drawCircle(
        Offset(p.x, p.y),
        _widthAt(baseWidth, p.pressure, isHighlighter) / 2,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final first = points.first.pressure;
    final constantPressure = isHighlighter ||
        points.every((p) => (p.pressure - first).abs() < 0.02);

    if (constantPressure) {
      paint.strokeWidth = _widthAt(baseWidth, first, isHighlighter);
      canvas.drawPath(_smoothPath(points), paint);
      return;
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      paint.strokeWidth =
          _widthAt(baseWidth, (a.pressure + b.pressure) / 2, false);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
    }
  }

  static double _widthAt(double base, double pressure, bool highlighter) {
    if (highlighter) return base;
    return base * (_minPressureFactor + (1 - _minPressureFactor) * pressure);
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