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
  static const double _gamma = 0.8; // <1 = more sensitive at low pressure
  static const double _follow = 0.35;

  static InkOutline? build(List<StrokePoint> input, double baseWidth) {
    final pts = <StrokePoint>[];
    for (final p in input) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      if (pts.isNotEmpty && _dist(pts.last, p) < 0.05) continue;
      pts.add(p);
    }
    if (pts.length < 3 || !baseWidth.isFinite) return null;

    final timed = pts.last.timestampMs > pts.first.timestampMs;
    final p0 = pts.first.pressure;
    final pressured = pts.any((p) => (p.pressure - p0).abs() > 0.02);
    if (!timed && !pressured) return null;

    final n = pts.length;
    final half = baseWidth / 2;

    // Raw thickness target per point.
    final raw = List<double>.filled(n, 1.0);
    for (var i = 0; i < n; i++) {
      if (pressured) {
        final pr = pts[i].pressure.isFinite ? pts[i].pressure : 1.0;
        final p = math.pow(pr.clamp(0.0, 1.0), _gamma).toDouble();
        raw[i] = _thin + (_thick - _thin) * p;
      } else {
        final a = pts[math.max(0, i - 1)];
        final b = pts[math.min(n - 1, i + 1)];
        final dt = math.max(1, b.timestampMs - a.timestampMs);
        final v = _dist(a, b) / dt;
        final t = ((v - _slow) / (_fast - _slow)).clamp(0.0, 1.0);
        final s = t * t * (3 - 2 * t);
        raw[i] = _thick + (_thin - _thick) * s;
      }
    }

    // Forward + backward smoothing: no lag, so no one-sided wedge/tilt look.
    final fwd = List<double>.of(raw);
    for (var i = 1; i < n; i++) {
      fwd[i] = fwd[i - 1] + (raw[i] - fwd[i - 1]) * _follow;
    }
    final bwd = List<double>.of(raw);
    for (var i = n - 2; i >= 0; i--) {
      bwd[i] = bwd[i + 1] + (raw[i] - bwd[i + 1]) * _follow;
    }

    final r = List<double>.filled(n, 0.25);
    for (var i = 0; i < n; i++) {
      final edge = math.min(i, n - 1 - i);
      final taper = edge >= _taper ? 1.0 : 0.35 + 0.65 * edge / _taper;
      final v = half * ((fwd[i] + bwd[i]) / 2) * taper;
      r[i] = v.isFinite ? math.max(0.25, v) : 0.25;
    }

    // Densify the centre line with Catmull-Rom so the outline is a smooth
    // curve instead of visible straight facets.
    final sub = n > 500 ? 1 : (n > 200 ? 2 : 3);
    final samples = <InkSample>[];
    for (var i = 0; i < n - 1; i++) {
      final a = pts[math.max(i - 1, 0)];
      final b = pts[i];
      final c = pts[i + 1];
      final d = pts[math.min(i + 2, n - 1)];
      for (var k = 0; k < sub; k++) {
        final t = k / sub;
        samples.add((
          x: _cr(a.x, b.x, c.x, d.x, t),
          y: _cr(a.y, b.y, c.y, d.y, t),
          r: r[i] + (r[i + 1] - r[i]) * t,
        ));
      }
    }
    samples.add((x: pts.last.x, y: pts.last.y, r: r[n - 1]));

    // No per-vertex alpha: constant opacity, thickness carries the pressure.
    return InkGeometry.offset(samples);
  }

  static double _cr(double a, double b, double c, double d, double t) =>
      0.5 *
      ((2 * b) +
          (-a + c) * t +
          (2 * a - 5 * b + 4 * c - d) * t * t +
          (-a + 3 * b - 3 * c + d) * t * t * t);

  static double _dist(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
