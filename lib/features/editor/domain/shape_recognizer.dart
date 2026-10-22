import 'dart:math' as math;

import 'stroke_point.dart';

typedef _P = ({double x, double y});
typedef _Box = ({double left, double top, double right, double bottom});

enum ShapeKind { line, arrow, triangle, rectangle, square, circle, ellipse }

/// A clean shape ready to be stored as a normal stroke.
final class RecognizedShape {
  const RecognizedShape(this.kind, this.points);

  final ShapeKind kind;
  final List<StrokePoint> points;
}

/// Turns a rough hand-drawn stroke into a precise shape. No Flutter imports.
///
/// Returns null when nothing matches, so the caller keeps the original
/// stroke. Thresholds are ratios of the stroke size, so they work at any
/// zoom level.
abstract final class ShapeRecognizer {
  /// Strokes shorter than this (document units) are handwriting, not shapes.
  static const double minPathLength = 60;
  static const double minDiagonal = 40;

  static const double _closeRatio = 0.16;
  static const double _lineMaxDeviation = 0.06;
  static const double _maxStretch = 1.12;
  static const double _axisSnap = 0.07; // radians, about 4 degrees
  static const double _ellipseMaxError = 0.10;
  static const double _polygonMaxError = 0.045;
  static const double _squareTolerance = 0.12;
  static const double _circleTolerance = 0.12;
  static const int _ringSize = 96;
  static const int _ellipseSteps = 72;

  static RecognizedShape? recognize(List<StrokePoint> input) {
    final pts = _clean(input);
    if (pts.length < 6) return null;

    final box = _bounds(pts);
    final diag = math.sqrt(
      math.pow(box.right - box.left, 2) + math.pow(box.bottom - box.top, 2),
    );
    final length = _pathLength(pts);
    if (length < minPathLength || diag < minDiagonal) return null;

    if (_dist(pts.first, pts.last) <= _closeRatio * length) {
      return _closed(pts, diag);
    }
    return _line(pts, length) ?? _arrow(pts, length);
  }

  // ---- Open shapes ----

  static RecognizedShape? _line(List<_P> pts, double length) {
    final a = pts.first;
    final b = pts.last;
    final chord = _dist(a, b);
    if (chord == 0 || length > chord * _maxStretch) return null;
    for (final p in pts) {
      if (_distToLine(p, a, b) > chord * _lineMaxDeviation) return null;
    }
    return RecognizedShape(ShapeKind.line, _plain([a, _snapEnd(a, b)]));
  }

  /// One-stroke arrow: a straight shaft, then one or two strokes of the
  /// head drawn back from the tip.
  static RecognizedShape? _arrow(List<_P> pts, double length) {
    final a = pts.first;
    var best = 0.0;
    for (final p in pts) {
      best = math.max(best, _dist(a, p));
    }
    var tipIndex = 0;
    for (var i = 0; i < pts.length; i++) {
      if (_dist(a, pts[i]) >= best * 0.97) {
        tipIndex = i;
        break;
      }
    }
    if (tipIndex < 2 || tipIndex > pts.length - 3) return null;

    final tip = pts[tipIndex];
    final shaft = _dist(a, tip);
    if (shaft == 0) return null;

    final shaftPoints = pts.sublist(0, tipIndex + 1);
    for (final p in shaftPoints) {
      if (_distToLine(p, a, tip) > shaft * 0.08) return null;
    }
    final shaftPath = _pathLength(shaftPoints);
    if (shaftPath > shaft * _maxStretch) return null;
    final headPath = length - shaftPath;
    if (headPath < shaft * 0.15 || headPath > shaft * 1.2) return null;

    final tips = _wingTips(pts.sublist(tipIndex), tip, shaft);
    if (tips.isEmpty || tips.length > 2) return null;

    final sx = a.x - tip.x;
    final sy = a.y - tip.y;
    final sl = math.sqrt(sx * sx + sy * sy);
    final lengths = <double>[];
    final angles = <double>[];
    final sides = <bool>[];
    for (final t in tips) {
      final vx = t.x - tip.x;
      final vy = t.y - tip.y;
      final vl = math.sqrt(vx * vx + vy * vy);
      if (vl == 0 || vl > shaft * 0.5) return null;
      final c = (vx * sx + vy * sy) / (vl * sl);
      // Wings must point backwards, neither along the shaft nor sideways.
      if (c < 0.26 || c > 0.98) return null;
      lengths.add(vl);
      angles.add(math.acos(c));
      sides.add(sx * vy - sy * vx > 0);
    }
    if (tips.length == 2 && sides[0] == sides[1]) return null;

    final end = _snapEnd(a, tip);
    final dx = a.x - end.x;
    final dy = a.y - end.y;
    final dl = math.sqrt(dx * dx + dy * dy);
    final ux = dx / dl;
    final uy = dy / dl;

    final wing = _avg(lengths).clamp(10.0, shaft * 0.3).toDouble();
    final angle = _avg(angles)
        .clamp(22 * math.pi / 180, 38 * math.pi / 180)
        .toDouble();
    _P wingEnd(double turn) => (
      x: end.x + wing * (ux * math.cos(turn) - uy * math.sin(turn)),
      y: end.y + wing * (ux * math.sin(turn) + uy * math.cos(turn)),
    );

    return RecognizedShape(
      ShapeKind.arrow,
      _corners([a, end, wingEnd(angle), end, wingEnd(-angle)]),
    );
  }

  /// Far points of the head, one per stroke that leaves the tip and comes
  /// back toward it.
  static List<_P> _wingTips(List<_P> head, _P tip, double shaft) {
    final enter = math.max(shaft * 0.08, 8.0);
    final tips = <_P>[];
    var inside = false;
    var peak = 0.0;
    _P? peakPoint;
    for (final p in head) {
      final d = _dist(p, tip);
      if (inside) {
        if (d > peak) {
          peak = d;
          peakPoint = p;
        } else if (d < peak * 0.5) {
          tips.add(peakPoint!);
          inside = false;
          peak = 0;
          peakPoint = null;
        }
      } else if (d > enter) {
        inside = true;
        peak = d;
        peakPoint = p;
      }
    }
    if (inside && peakPoint != null) tips.add(peakPoint);
    return tips;
  }

  /// Snaps a line end to horizontal, vertical or 45 degrees when close.
  static _P _snapEnd(_P a, _P b) {
    final chord = _dist(a, b);
    final angle = math.atan2(b.y - a.y, b.x - a.x);
    const step = math.pi / 4;
    final snapped = (angle / step).roundToDouble() * step;
    if ((angle - snapped).abs() > _axisSnap) return b;
    return (
      x: a.x + chord * math.cos(snapped),
      y: a.y + chord * math.sin(snapped),
    );
  }

  // ---- Closed shapes ----

  static RecognizedShape? _closed(List<_P> pts, double diag) {
    final ring = _resample(pts, _ringSize);
    final box = _bounds(ring);
    final w = box.right - box.left;
    final h = box.bottom - box.top;
    if (math.min(w, h) < diag * 0.1) return null;

    final cx = (box.left + box.right) / 2;
    final cy = (box.top + box.bottom) / 2;
    final rx = w / 2;
    final ry = h / 2;
    final ellipseError = _ellipseError(ring, cx, cy, rx, ry);

    final rect = _fitRectangle(ring);
    final tri = _fitTriangle(ring, diag);
    final polyError = math.min(rect?.error ?? 9, tri?.error ?? 9);

    final preferPolygon = polyError <= _polygonMaxError && ellipseError > 0.07;
    if (ellipseError <= _ellipseMaxError && !preferPolygon) {
      return _ellipse(cx, cy, rx, ry);
    }
    if (polyError > _polygonMaxError) return null;

    if (rect != null && rect.error == polyError) {
      final square =
          (rect.w - rect.h).abs() <=
          _squareTolerance * math.max(rect.w, rect.h);
      return RecognizedShape(
        square ? ShapeKind.square : ShapeKind.rectangle,
        _corners(_rectCorners(rect, square), close: true),
      );
    }
    return RecognizedShape(
      ShapeKind.triangle,
      _corners(tri!.vertices, close: true),
    );
  }

  static RecognizedShape _ellipse(double cx, double cy, double rx, double ry) {
    final circle = (rx - ry).abs() <= _circleTolerance * math.max(rx, ry);
    final a = circle ? (rx + ry) / 2 : rx;
    final b = circle ? a : ry;
    return RecognizedShape(circle ? ShapeKind.circle : ShapeKind.ellipse, [
      for (var i = 0; i <= _ellipseSteps; i++)
        StrokePoint(
          x: cx + a * math.cos(2 * math.pi * i / _ellipseSteps),
          y: cy + b * math.sin(2 * math.pi * i / _ellipseSteps),
        ),
    ]);
  }

  static double _ellipseError(
    List<_P> ring,
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    var sum = 0.0;
    for (final p in ring) {
      final t = math.sqrt(
        math.pow((p.x - cx) / rx, 2) + math.pow((p.y - cy) / ry, 2),
      );
      sum += (t - 1) * (t - 1);
    }
    return math.sqrt(sum / ring.length);
  }

  /// Smallest rotated bounding box of the ring, if the ring really visits
  /// its four corners.
  static _RectFit? _fitRectangle(List<_P> ring) {
    var bestArea = double.infinity;
    var bestDeg = 0;
    for (var deg = 0; deg < 90; deg++) {
      final box = _bounds(_rotate(ring, deg * math.pi / 180));
      final area = (box.right - box.left) * (box.bottom - box.top);
      if (area < bestArea) {
        bestArea = area;
        bestDeg = deg;
      }
    }
    if (bestDeg <= 6 || bestDeg >= 84) bestDeg = 0;

    final angle = bestDeg * math.pi / 180;
    final rotated = _rotate(ring, angle);
    final box = _bounds(rotated);
    final w = box.right - box.left;
    final h = box.bottom - box.top;
    if (math.min(w, h) <= 0) return null;

    var sum = 0.0;
    for (final p in rotated) {
      final d = math.min(
        math.min(p.x - box.left, box.right - p.x),
        math.min(p.y - box.top, box.bottom - p.y),
      );
      sum += d * d;
    }
    final error = math.sqrt(sum / rotated.length) / math.sqrt(w * w + h * h);

    final corners = <_P>[
      (x: box.left, y: box.top),
      (x: box.right, y: box.top),
      (x: box.right, y: box.bottom),
      (x: box.left, y: box.bottom),
    ];
    for (final c in corners) {
      var nearest = double.infinity;
      for (final p in rotated) {
        nearest = math.min(nearest, _dist(p, c));
      }
      if (nearest > 0.17 * math.min(w, h)) return null;
    }
    return _RectFit(error: error, box: box, angle: angle, w: w, h: h);
  }

  static List<_P> _rectCorners(_RectFit fit, bool square) {
    var l = fit.box.left;
    var t = fit.box.top;
    var r = fit.box.right;
    var b = fit.box.bottom;
    if (square) {
      final side = (fit.w + fit.h) / 2;
      final cx = (l + r) / 2;
      final cy = (t + b) / 2;
      l = cx - side / 2;
      r = cx + side / 2;
      t = cy - side / 2;
      b = cy + side / 2;
    }
    final c = math.cos(fit.angle);
    final s = math.sin(fit.angle);
    _P back(double x, double y) => (x: x * c - y * s, y: x * s + y * c);
    return [back(l, t), back(r, t), back(r, b), back(l, b)];
  }

  static _TriFit? _fitTriangle(List<_P> ring, double diag) {
    for (final k in const [0.05, 0.08, 0.12]) {
      final v = _simplifyClosed(ring, k * diag);
      if (v.length < 3) return null;
      if (v.length != 3) continue;

      var sum = 0.0;
      for (final p in ring) {
        var d = double.infinity;
        for (var i = 0; i < 3; i++) {
          d = math.min(d, _distToSegment(p, v[i], v[(i + 1) % 3]));
        }
        sum += d * d;
      }
      final area =
          ((v[1].x - v[0].x) * (v[2].y - v[0].y) -
                  (v[2].x - v[0].x) * (v[1].y - v[0].y))
              .abs() /
          2;
      if (area < 0.04 * diag * diag) return null;
      return _TriFit(error: math.sqrt(sum / ring.length) / diag, vertices: v);
    }
    return null;
  }

  // ---- Geometry helpers ----

  static List<_P> _simplifyClosed(List<_P> ring, double eps) {
    var far = 0;
    var best = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final d = _dist(ring.first, ring[i]);
      if (d > best) {
        best = d;
        far = i;
      }
    }
    final a = _rdp(ring.sublist(0, far + 1), eps);
    final b = _rdp([...ring.sublist(far), ring.first], eps);
    return [...a, ...b.sublist(1, b.length - 1)];
  }

  static List<_P> _rdp(List<_P> p, double eps) {
    if (p.length < 3) return List<_P>.of(p);
    var index = 0;
    var maxDist = 0.0;
    for (var i = 1; i < p.length - 1; i++) {
      final d = _distToSegment(p[i], p.first, p.last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist <= eps) return [p.first, p.last];
    final left = _rdp(p.sublist(0, index + 1), eps);
    final right = _rdp(p.sublist(index), eps);
    return [...left.sublist(0, left.length - 1), ...right];
  }

  /// [n] points spaced evenly along the path.
  static List<_P> _resample(List<_P> p, int n) {
    final total = _pathLength(p);
    if (total == 0) return List<_P>.filled(n, p.first);
    final step = total / (n - 1);
    final out = <_P>[p.first];
    var prev = p.first;
    var remaining = step;
    var i = 1;
    while (i < p.length && out.length < n - 1) {
      final next = p[i];
      final d = _dist(prev, next);
      if (d >= remaining && d > 0) {
        final t = remaining / d;
        prev = (
          x: prev.x + (next.x - prev.x) * t,
          y: prev.y + (next.y - prev.y) * t,
        );
        out.add(prev);
        remaining = step;
      } else {
        remaining -= d;
        prev = next;
        i++;
      }
    }
    while (out.length < n) {
      out.add(p.last);
    }
    out[n - 1] = p.last;
    return out;
  }

  static List<_P> _rotate(List<_P> p, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return [for (final q in p) (x: q.x * c + q.y * s, y: -q.x * s + q.y * c)];
  }

  static List<_P> _clean(List<StrokePoint> input) {
    final out = <_P>[];
    for (final p in input) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      final q = (x: p.x, y: p.y);
      if (out.isNotEmpty && _dist(out.last, q) < 0.5) continue;
      out.add(q);
    }
    return out;
  }

  static _Box _bounds(List<_P> p) {
    var l = p.first.x, r = p.first.x, t = p.first.y, b = p.first.y;
    for (final q in p) {
      l = math.min(l, q.x);
      r = math.max(r, q.x);
      t = math.min(t, q.y);
      b = math.max(b, q.y);
    }
    return (left: l, top: t, right: r, bottom: b);
  }

  static double _pathLength(List<_P> p) {
    var sum = 0.0;
    for (var i = 1; i < p.length; i++) {
      sum += _dist(p[i - 1], p[i]);
    }
    return sum;
  }

  static double _dist(_P a, _P b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _distToLine(_P p, _P a, _P b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final l = math.sqrt(dx * dx + dy * dy);
    if (l == 0) return _dist(p, a);
    return ((p.x - a.x) * dy - (p.y - a.y) * dx).abs() / l;
  }

  static double _distToSegment(_P p, _P a, _P b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return _dist(p, a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)
        .clamp(0.0, 1.0)
        .toDouble();
    return _dist(p, (x: a.x + t * dx, y: a.y + t * dy));
  }

  static double _avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;

  static List<StrokePoint> _plain(List<_P> v) => [
    for (final p in v) StrokePoint(x: p.x, y: p.y),
  ];

  /// Every corner is written twice so the smoothing in InkRenderer keeps
  /// the corners sharp.
  static List<StrokePoint> _corners(List<_P> v, {bool close = false}) {
    final all = close ? [...v, v.first] : v;
    return [
      for (final p in all) ...[
        StrokePoint(x: p.x, y: p.y),
        StrokePoint(x: p.x, y: p.y),
      ],
    ];
  }
}

final class _RectFit {
  const _RectFit({
    required this.error,
    required this.box,
    required this.angle,
    required this.w,
    required this.h,
  });

  final double error;
  final _Box box;
  final double angle;
  final double w;
  final double h;
}

final class _TriFit {
  const _TriFit({required this.error, required this.vertices});

  final double error;
  final List<_P> vertices;
}
