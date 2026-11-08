import 'dart:math' as math;

import 'stroke_point.dart';

typedef ArrowPoint = ({double x, double y});
typedef ArrowWing = ({double length, double angle});

/// Arrow = 5 corners, each written twice (10 points):
/// tail, tip, wing1, tip, wing2. Tail is points[0], tip is points[2].
abstract final class ArrowShape {
  static const int pointCount = 10;
  static const double _defaultAngle = 28 * math.pi / 180;

  static List<StrokePoint> build(
    ArrowPoint tail,
    ArrowPoint tip, {
    List<ArrowWing>? wings,
  }) {
    final dx = tail.x - tip.x, dy = tail.y - tip.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) {
      return [StrokePoint(x: tip.x, y: tip.y), StrokePoint(x: tip.x, y: tip.y)];
    }
    final ux = dx / len, uy = dy / len;
    final maxWing = math.max(10.0, len * 0.3);
    final w =
        wings ??
        () {
          final l = math.min(36.0, len * 0.3);
          return <ArrowWing>[
            (length: l, angle: _defaultAngle),
            (length: l, angle: -_defaultAngle),
          ];
        }();

    ArrowPoint wingEnd(ArrowWing wing) {
      final l = math.min(wing.length, maxWing);
      final c = math.cos(wing.angle), s = math.sin(wing.angle);
      return (
        x: tip.x + l * (ux * c - uy * s),
        y: tip.y + l * (ux * s + uy * c),
      );
    }

    final pts = [tail, tip, wingEnd(w[0]), tip, wingEnd(w[1])];
    return [
      for (final p in pts) ...[
        StrokePoint(x: p.x, y: p.y),
        StrokePoint(x: p.x, y: p.y),
      ],
    ];
  }

  /// Moves tail and/or tip, keeping the wing length and angle of [old].
  static List<StrokePoint> rebuild(
    List<StrokePoint> old, {
    required ArrowPoint tail,
    required ArrowPoint tip,
  }) {
    if (old.length != pointCount) return build(tail, tip);
    final t0 = old[2], a0 = old[0];
    final ux = a0.x - t0.x, uy = a0.y - t0.y;
    final len0 = math.sqrt(ux * ux + uy * uy);
    if (len0 < 1e-6) return build(tail, tip);

    ArrowWing wing(StrokePoint p) {
      final vx = p.x - t0.x, vy = p.y - t0.y;
      return (
        length: math.sqrt(vx * vx + vy * vy),
        angle: math.atan2(ux * vy - uy * vx, ux * vx + uy * vy),
      );
    }

    return build(tail, tip, wings: [wing(old[4]), wing(old[8])]);
  }
}
