import 'dart:math' as math;

import 'ink_geometry.dart';
import 'stroke_point.dart';

/// Pressure / speed based width for the Physical Pen. No Flutter imports.
/// Returns null when the points carry no pressure or timing (snapped
/// shapes), so the caller draws a normal constant-width line.
abstract final class PhysicalInk {
  static const double _slow = 0.12; // document units per ms
  static const double _fast = 1.8;
  static const double _thick = 1.25;
  static const double _thin = 0.45;
  static const int _taper = 6;

  static InkOutline? build(List<StrokePoint> input, double baseWidth) {
    final pts = <StrokePoint>[];
    for (final p in input) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      if (pts.isNotEmpty && _dist(pts.last, p) < 0.05) continue;
      pts.add(p);
    }
    if (pts.length < 3) return null;

    final timed = pts.last.timestampMs > pts.first.timestampMs;
    final p0 = pts.first.pressure;
    final pressured = pts.any((p) => (p.pressure - p0).abs() > 0.02);
    if (!timed && !pressured) return null;

    final half = baseWidth / 2;
    final samples = <InkSample>[];
    var level = 1.0;
    for (var i = 0; i < pts.length; i++) {
      final double target;
      if (pressured) {
        target = _thin + (_thick - _thin) * pts[i].pressure.clamp(0.0, 1.0);
      } else {
        final a = pts[math.max(0, i - 1)];
        final b = pts[math.min(pts.length - 1, i + 1)];
        final dt = math.max(1, b.timestampMs - a.timestampMs);
        final v = _dist(a, b) / dt;
        final t = ((v - _slow) / (_fast - _slow)).clamp(0.0, 1.0);
        final s = t * t * (3 - 2 * t);
        target = _thick + (_thin - _thick) * s;
      }
      level += (target - level) * 0.3;
      final edge = math.min(i, pts.length - 1 - i);
      final taper = edge >= _taper ? 1.0 : 0.35 + 0.65 * edge / _taper;
      samples.add((
        x: pts[i].x,
        y: pts[i].y,
        r: math.max(0.25, half * level * taper),
      ));
    }
    return InkGeometry.offset(samples);
  }

  static double _dist(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
