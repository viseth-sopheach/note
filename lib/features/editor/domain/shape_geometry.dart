import 'dart:math' as math;

import 'stroke_point.dart';
import 'stroke_tool.dart';

typedef Segment = ({double ax, double ay, double bx, double by});

/// Turns a drag into a polyline and holds snapping math. No Flutter imports.
/// Shapes are saved as normal pen strokes, so undo, erase, select, move,
/// save and PDF export all work without changes.
abstract final class ShapeGeometry {
  static const int _ellipseSteps = 72;
  static const double _lineStep = math.pi / 12; // 15 degrees

  static bool isUsable(double x0, double y0, double x1, double y1) =>
      (x1 - x0).abs() >= 2 || (y1 - y0).abs() >= 2;

  static List<StrokePoint> build(
    StrokeTool tool, {
    required double x0,
    required double y0,
    required double x1,
    required double y1,
    bool constrain = false,
  }) {
    var dx = x1 - x0;
    var dy = y1 - y0;
    if (constrain) {
      if (tool == StrokeTool.line) {
        final len = math.sqrt(dx * dx + dy * dy);
        final a = (math.atan2(dy, dx) / _lineStep).roundToDouble() * _lineStep;
        dx = len * math.cos(a);
        dy = len * math.sin(a);
      } else {
        final s = math.max(dx.abs(), dy.abs());
        dx = dx < 0 ? -s : s;
        dy = dy < 0 ? -s : s;
      }
    }
    final ex = x0 + dx;
    final ey = y0 + dy;
    final left = math.min(x0, ex);
    final right = math.max(x0, ex);
    final top = math.min(y0, ey);
    final bottom = math.max(y0, ey);

    switch (tool) {
      case StrokeTool.rectangle:
        return _closed([
          (left, top),
          (right, top),
          (right, bottom),
          (left, bottom),
        ]);
      case StrokeTool.triangle:
        return _closed([
          ((left + right) / 2, top),
          (right, bottom),
          (left, bottom),
        ]);
      case StrokeTool.ellipse:
        final cx = (left + right) / 2;
        final cy = (top + bottom) / 2;
        final rx = (right - left) / 2;
        final ry = (bottom - top) / 2;
        return [
          for (var i = 0; i <= _ellipseSteps; i++)
            StrokePoint(
              x: cx + rx * math.cos(2 * math.pi * i / _ellipseSteps),
              y: cy + ry * math.sin(2 * math.pi * i / _ellipseSteps),
            ),
        ];
      default:
        return [StrokePoint(x: x0, y: y0), StrokePoint(x: ex, y: ey)];
    }
  }

  /// Every corner is written twice so the smoothing in InkRenderer keeps
  /// the corners sharp.
  static List<StrokePoint> _closed(List<(double, double)> v) {
    final out = <StrokePoint>[];
    for (final (x, y) in [...v, v.first]) {
      out
        ..add(StrokePoint(x: x, y: y))
        ..add(StrokePoint(x: x, y: y));
    }
    return out;
  }

  static ({double x, double y}) project(Segment s, double px, double py) {
    final dx = s.bx - s.ax;
    final dy = s.by - s.ay;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return (x: s.ax, y: s.ay);
    final t =
        (((px - s.ax) * dx + (py - s.ay) * dy) / l2).clamp(0.0, 1.0).toDouble();
    return (x: s.ax + t * dx, y: s.ay + t * dy);
  }

  static double distanceToSegment(Segment s, double px, double py) {
    final p = project(s, px, py);
    final dx = px - p.x;
    final dy = py - p.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}