import 'dart:ui';

import '../../domain/ink_geometry.dart';
import '../../domain/physical_ink.dart';
import '../../domain/stroke_point.dart';
import '../../domain/stroke_tool.dart';

/// Draws one stroke. Every stroke is a monoline: a constant-width stroke
/// along the untouched recorded path, with round caps and round joins.
/// Highlighter is the same geometry at a wider width and lower opacity.
abstract final class InkRenderer {
  static const double highlighterWidthScale = 6;
  static const double highlighterAlpha = 0.35;
  static const double fillAlpha = 0.3;

  static void paintStroke(
    Canvas canvas, {
    required List<StrokePoint> points,
    required StrokeTool tool,
    required int colorValue,
    required double width,
    int? fillColorValue,
  }) {
    if (points.isEmpty) return;

    final isHighlighter = tool == StrokeTool.highlighter;
    final strokeWidth = isHighlighter ? width * highlighterWidthScale : width;
    var color = Color(colorValue);
    if (isHighlighter) color = color.withValues(alpha: highlighterAlpha);

    if (fillColorValue != null && points.length >= 3) {
      final area = Path()..moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        area.lineTo(p.x, p.y);
      }
      area.close();
      canvas.drawPath(
        area,
        Paint()
          ..color = Color(fillColorValue).withValues(alpha: fillAlpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

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

    if (tool.isNaturalPen && points.length >= 3) {
      final outline = PhysicalInk.build(points, width);
      if (outline != null) {
        _paintPressure(canvas, outline, color);
        return;
      }
    }

    canvas.drawPath(
      _smoothPath(points),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  /// Triangle strip with per-vertex alpha: width and opacity change smoothly
  /// along the stroke without overlap seams.
  static void _paintPressure(Canvas canvas, InkOutline o, Color color) {
    final n = o.left.length;
    final positions = <Offset>[];
    final colors = <Color>[];
    for (var i = 0; i < n; i++) {
      final a = o.alphas == null ? 1.0 : o.alphas![i];
      final c = color.withValues(alpha: color.a * a);
      positions
        ..add(Offset(o.left[i].x, o.left[i].y))
        ..add(Offset(o.right[i].x, o.right[i].y));
      colors
        ..add(c)
        ..add(c);
    }
    final vertices = Vertices(
      VertexMode.triangleStrip,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();

    final capPaint = Paint()..isAntiAlias = true;
    for (final (s, a) in [
      (o.start, o.alphas?.first ?? 1.0),
      (o.end, o.alphas?.last ?? 1.0),
    ]) {
      capPaint.color = color.withValues(alpha: color.a * a);
      canvas.drawCircle(Offset(s.x, s.y), s.r, capPaint);
    }
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
