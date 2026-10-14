import 'dart:math' as math;

import 'stroke.dart';
import 'stroke_tool.dart';

/// Hit testing of strokes in document coordinates. No Flutter imports.
abstract final class StrokeHitTest {
  /// Must match InkRenderer.highlighterWidthScale.
  static const double highlighterWidthScale = 6;

  /// True when the segment (ax, ay) to (bx, by), thickened by [radius],
  /// touches the stroke.
  static bool hitsSegment(
    Stroke stroke, {
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double radius,
  }) {
    final points = stroke.points;
    if (points.isEmpty) return false;
    final reach = radius + _halfWidth(stroke);

    if (points.length == 1) {
      final p = points.first;
      return _pointSegmentDistance(p.x, p.y, ax, ay, bx, by) <= reach;
    }

    for (var i = 1; i < points.length; i++) {
      final p = points[i - 1];
      final q = points[i];
      if (_segmentDistance(p.x, p.y, q.x, q.y, ax, ay, bx, by) <= reach) {
        return true;
      }
    }
    return false;
  }

  static double _halfWidth(Stroke stroke) {
    final scale =
        stroke.tool == StrokeTool.highlighter ? highlighterWidthScale : 1;
    return stroke.width * scale / 2;
  }

  static double _pointSegmentDistance(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }
    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared)
        .clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  static double _cross(
    double ox,
    double oy,
    double px,
    double py,
    double qx,
    double qy,
  ) =>
      (px - ox) * (qy - oy) - (py - oy) * (qx - ox);

  static double _segmentDistance(
    double a1x,
    double a1y,
    double a2x,
    double a2y,
    double b1x,
    double b1y,
    double b2x,
    double b2y,
  ) {
    final d1 = _cross(b1x, b1y, b2x, b2y, a1x, a1y);
    final d2 = _cross(b1x, b1y, b2x, b2y, a2x, a2y);
    final d3 = _cross(a1x, a1y, a2x, a2y, b1x, b1y);
    final d4 = _cross(a1x, a1y, a2x, a2y, b2x, b2y);
    if (d1 * d2 < 0 && d3 * d4 < 0) return 0;

    return math.min(
      math.min(
        _pointSegmentDistance(a1x, a1y, b1x, b1y, b2x, b2y),
        _pointSegmentDistance(a2x, a2y, b1x, b1y, b2x, b2y),
      ),
      math.min(
        _pointSegmentDistance(b1x, b1y, a1x, a1y, a2x, a2y),
        _pointSegmentDistance(b2x, b2y, a1x, a1y, a2x, a2y),
      ),
    );
  }
}