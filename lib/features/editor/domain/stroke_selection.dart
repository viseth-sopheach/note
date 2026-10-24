import 'dart:math' as math;

import 'stroke.dart';
import 'stroke_hit_test.dart';
import 'stroke_point.dart';
import 'stroke_tool.dart';

typedef Vertex = ({double x, double y});
typedef Bounds = ({double left, double top, double right, double bottom});

/// Lasso selection, bounds and translation of strokes. No Flutter imports.
abstract final class StrokeSelection {
  /// Ray casting point-in-polygon test.
  static bool contains(List<Vertex> polygon, double x, double y) {
    var inside = false;
    final n = polygon.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.y > y) != (b.y > y) &&
          x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Ids of strokes with at least half of their points inside [lasso].
  static Set<String> insideLasso(List<Stroke> strokes, List<Vertex> lasso) {
    if (lasso.length < 3) return {};
    final ids = <String>{};
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      var inside = 0;
      for (final p in s.points) {
        if (contains(lasso, p.x, p.y)) inside++;
      }
      if (inside * 2 >= s.points.length) ids.add(s.id);
    }
    return ids;
  }

  /// Bounds of all [strokes] including half their width, or null if empty.
  static Bounds? boundsOf(Iterable<Stroke> strokes) {
    double? left, top, right, bottom;
    for (final s in strokes) {
      final scale = s.tool == StrokeTool.highlighter
          ? StrokeHitTest.highlighterWidthScale
          : 1;
      final half = s.width * scale / 2;
      for (final p in s.points) {
        final l = p.x - half, t = p.y - half, r = p.x + half, b = p.y + half;
        left = left == null || l < left ? l : left;
        top = top == null || t < top ? t : top;
        right = right == null || r > right ? r : right;
        bottom = bottom == null || b > bottom ? b : bottom;
      }
    }
    if (left == null) return null;
    return (left: left, top: top!, right: right!, bottom: bottom!);
  }

  static Stroke translate(Stroke stroke, double dx, double dy) =>
      stroke.copyWith(
        points: [
          for (final p in stroke.points)
            StrokePoint(
              x: p.x + dx,
              y: p.y + dy,
              pressure: p.pressure,
              timestampMs: p.timestampMs,
            ),
        ],
      );

  /// Bounds of the points only, without stroke width. Null if empty.
  static Bounds? pointBoundsOf(Iterable<Stroke> strokes) {
    double? left, top, right, bottom;
    for (final s in strokes) {
      for (final p in s.points) {
        left = left == null || p.x < left ? p.x : left;
        top = top == null || p.y < top ? p.y : top;
        right = right == null || p.x > right ? p.x : right;
        bottom = bottom == null || p.y > bottom ? p.y : bottom;
      }
    }
    if (left == null) return null;
    return (left: left, top: top!, right: right!, bottom: bottom!);
  }

  /// Scales the points about (ax, ay). Width, color and pressure are kept.
  static Stroke scaleAbout(
    Stroke stroke,
    double ax,
    double ay,
    double sx,
    double sy,
  ) => stroke.copyWith(
    points: [
      for (final p in stroke.points)
        StrokePoint(
          x: ax + (p.x - ax) * sx,
          y: ay + (p.y - ay) * sy,
          pressure: p.pressure,
          timestampMs: p.timestampMs,
        ),
    ],
  );

  static double _gap(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Open stroke whose ends are far apart relative to its length.
  static bool isClosed(Stroke s) {
    final p = s.points;
    if (p.length < 3) return false;
    var path = 0.0;
    for (var i = 1; i < p.length; i++) {
      path += _gap(p[i - 1], p[i]);
    }
    return path > 0 && _gap(p.first, p.last) <= 0.15 * path;
  }

  /// Start and end of a line, arrow or open freehand stroke; null for
  /// closed shapes, dots and compact scribbles. For arrows the end is the
  /// tip (the farthest point), otherwise the last point.
  static ({Vertex start, Vertex end})? linearEnds(Stroke s) {
    final p = s.points;
    if (p.length < 2 || isClosed(s)) return null;
    final a = p.first;
    var path = 0.0, far = 0.0;
    var farIndex = 0;
    for (var i = 1; i < p.length; i++) {
      path += _gap(p[i - 1], p[i]);
      final d = _gap(a, p[i]);
      if (d > far) {
        far = d;
        farIndex = i;
      }
    }
    if (path <= 0 || far < 0.3 * path) return null;
    final end = _gap(a, p.last) >= 0.9 * far ? p.last : p[farIndex];
    return (start: (x: a.x, y: a.y), end: (x: end.x, y: end.y));
  }

  /// Rotates and scales the points about (ax, ay) by the complex factor
  /// a + bi. Width, color and pressure are kept.
  static Stroke similarityAbout(
    Stroke stroke,
    double ax,
    double ay,
    double a,
    double b,
  ) => stroke.copyWith(
    points: [
      for (final p in stroke.points)
        StrokePoint(
          x: ax + a * (p.x - ax) - b * (p.y - ay),
          y: ay + b * (p.x - ax) + a * (p.y - ay),
          pressure: p.pressure,
          timestampMs: p.timestampMs,
        ),
    ],
  );
}
