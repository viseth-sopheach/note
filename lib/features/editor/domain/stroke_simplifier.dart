import 'stroke_point.dart';

/// Iterative Ramer-Douglas-Peucker. Keeps the original points (pressure and
/// timestamps stay intact), and always keeps the first and last point.
abstract final class StrokeSimplifier {
  /// [epsilon] is in document units. 0.25 stays invisible even at 4x zoom.
  static List<StrokePoint> rdp(List<StrokePoint> pts, {double epsilon = 0.25}) {
    final n = pts.length;
    if (n < 3) return pts;

    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;

    final eps2 = epsilon * epsilon;
    final stack = <(int, int)>[(0, n - 1)];
    while (stack.isNotEmpty) {
      final (s, e) = stack.removeLast();
      var maxD = 0.0;
      var index = -1;
      for (var i = s + 1; i < e; i++) {
        final d = _sqDistToSegment(pts[i], pts[s], pts[e]);
        if (d > maxD) {
          maxD = d;
          index = i;
        }
      }
      if (index != -1 && maxD > eps2) {
        keep[index] = true;
        stack
          ..add((s, index))
          ..add((index, e));
      }
    }
    return [
      for (var i = 0; i < n; i++)
        if (keep[i]) pts[i],
    ];
  }

  static double _sqDistToSegment(StrokePoint p, StrokePoint a, StrokePoint b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) {
      final ex = p.x - a.x, ey = p.y - a.y;
      return ex * ex + ey * ey;
    }
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).clamp(0.0, 1.0);
    final cx = a.x + t * dx - p.x, cy = a.y + t * dy - p.y;
    return cx * cx + cy * cy;
  }
}
