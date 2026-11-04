import 'dart:math' as math;

import 'stroke_point.dart';

typedef InkVertex = ({double x, double y});

/// Centre-line sample; [r] is the half width.
typedef InkSample = ({double x, double y, double r});

final class InkOutline {
  const InkOutline({
    required this.left,
    required this.right,
    required this.start,
    required this.end,
  });

  final List<InkVertex> left;
  final List<InkVertex> right;
  final InkSample start;
  final InkSample end;
}

/// Variable-width ink geometry. No Flutter imports.
///
/// Width comes from stylus pressure when it varies, otherwise from pointer
/// speed (slow = thicker, fast = thinner). Both ends taper. Strokes whose
/// points all share one timestamp and pressure (shapes, snapped shapes)
/// are not variable and keep a constant width.
abstract final class InkGeometry {
  static const double _minPressureFactor = 0.35;
  static const double _slowSpeed = 0.25; // document units per ms
  static const double _fastSpeed = 2.5;
  static const int _speedWindow = 3;

  static bool usesVariableWidth(List<StrokePoint> pts) {
    if (pts.length < 3) return false;
    final first = pts.first;
    for (final p in pts) {
      if ((p.pressure - first.pressure).abs() >= 0.02) return true;
      if (p.timestampMs != first.timestampMs) return true;
    }
    return false;
  }

  /// Returns null when the stroke is too short for an outline.
  static InkOutline? build(List<StrokePoint> input, double baseWidth) {
    final pts = _dedupe(input);
    if (pts.length < 3) return null;
    final factors = _factors(pts);
    _taper(pts, factors, baseWidth);
    final centre = _smooth(pts, factors, baseWidth / 2);
    return _offset(centre);
  }

  // ---- Width ----

  static List<double> _factors(List<StrokePoint> p) {
    final first = p.first;
    final pressureVaries = p.any(
      (q) => (q.pressure - first.pressure).abs() >= 0.02,
    );

    final f = pressureVaries
        ? [
            for (final q in p)
              _minPressureFactor +
                  (1 - _minPressureFactor) * q.pressure.clamp(0.0, 1.0),
          ]
        : _speedFactors(p);

    return _relax(_relax(f));
  }

  static List<double> _speedFactors(List<StrokePoint> p) {
    final speeds = <double>[];
    for (var i = 0; i < p.length; i++) {
      final j = math.max(0, i - _speedWindow);
      if (i == j) {
        speeds.add(0);
        continue;
      }
      final dt = math.max(1, p[i].timestampMs - p[j].timestampMs);
      speeds.add(_dist(p[i], p[j]) / dt);
    }
    var s = speeds.length > 1 ? speeds[1] : 0.0;
    final out = <double>[];
    for (final v in speeds) {
      s += (v - s) * 0.25;
      final t = ((s - _slowSpeed) / (_fastSpeed - _slowSpeed))
          .clamp(0.0, 1.0)
          .toDouble();
      out.add(1.1 - 0.5 * t);
    }
    return out;
  }

  static List<double> _relax(List<double> f) {
    if (f.length < 3) return f;
    final out = List<double>.of(f);
    for (var i = 1; i < f.length - 1; i++) {
      out[i] = 0.25 * f[i - 1] + 0.5 * f[i] + 0.25 * f[i + 1];
    }
    return out;
  }

  static void _taper(
    List<StrokePoint> p,
    List<double> f,
    double baseWidth,
  ) {
    final cum = <double>[0];
    for (var i = 1; i < p.length; i++) {
      cum.add(cum.last + _dist(p[i - 1], p[i]));
    }
    final total = cum.last;
    if (total < 6) return;
    final startLen = math.min(total * 0.25, baseWidth * 2 + 4);
    final endLen = math.min(total * 0.4, baseWidth * 5 + 8);
    for (var i = 0; i < p.length; i++) {
      var k = 1.0;
      final fromStart = cum[i];
      final fromEnd = total - cum[i];
      if (fromStart < startLen) {
        k = math.min(k, _ramp(fromStart / startLen, 0.45));
      }
      if (fromEnd < endLen) {
        k = math.min(k, _ramp(fromEnd / endLen, 0.12));
      }
      f[i] *= k;
    }
  }

  static double _ramp(double t, double floor) {
    final e = 1 - (1 - t) * (1 - t);
    return floor + (1 - floor) * e;
  }

  // ---- Centre line and outline ----

  /// Quadratic Bezier through the midpoints of the samples.
  static List<InkSample> _smooth(
    List<StrokePoint> p,
    List<double> f,
    double half,
  ) {
    final n = p.length;
    final out = <InkSample>[(x: p[0].x, y: p[0].y, r: half * f[0])];
    var cx = p[0].x, cy = p[0].y, cr = half * f[0];

    for (var i = 1; i < n - 1; i++) {
      final mx = (p[i].x + p[i + 1].x) / 2;
      final my = (p[i].y + p[i + 1].y) / 2;
      final mr = half * (f[i] + f[i + 1]) / 2;
      final len =
          math.sqrt(math.pow(p[i].x - cx, 2) + math.pow(p[i].y - cy, 2)) +
          math.sqrt(math.pow(mx - p[i].x, 2) + math.pow(my - p[i].y, 2));
      final steps = math.max(1, math.min(10, (len / 3).ceil()));
      for (var k = 1; k <= steps; k++) {
        final t = k / steps;
        final u = 1 - t;
        out.add((
          x: u * u * cx + 2 * u * t * p[i].x + t * t * mx,
          y: u * u * cy + 2 * u * t * p[i].y + t * t * my,
          r: cr + (mr - cr) * t,
        ));
      }
      cx = mx;
      cy = my;
      cr = mr;
    }
    out.add((x: p[n - 1].x, y: p[n - 1].y, r: half * f[n - 1]));
    return out;
  }

  static InkOutline _offset(List<InkSample> c) {
    final left = <InkVertex>[];
    final right = <InkVertex>[];
    var tx = 1.0, ty = 0.0;
    for (var j = 0; j < c.length; j++) {
      final a = c[math.max(0, j - 1)];
      final b = c[math.min(c.length - 1, j + 1)];
      final dx = b.x - a.x, dy = b.y - a.y;
      final l = math.sqrt(dx * dx + dy * dy);
      if (l > 1e-9) {
        tx = dx / l;
        ty = dy / l;
      }
      final nx = -ty, ny = tx;
      left.add((x: c[j].x + nx * c[j].r, y: c[j].y + ny * c[j].r));
      right.add((x: c[j].x - nx * c[j].r, y: c[j].y - ny * c[j].r));
    }
    return InkOutline(left: left, right: right, start: c.first, end: c.last);
  }

  // ---- Helpers ----

  static List<StrokePoint> _dedupe(List<StrokePoint> input) {
    final out = <StrokePoint>[];
    for (final p in input) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      if (out.isNotEmpty && _dist(out.last, p) < 0.05) continue;
      out.add(p);
    }
    return out;
  }

  static double _dist(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}