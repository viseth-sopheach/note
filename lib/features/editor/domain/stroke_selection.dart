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
}
