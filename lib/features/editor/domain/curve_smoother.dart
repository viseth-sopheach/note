import 'dart:math' as math;

import 'stroke_point.dart';

/// Gentle, corner-preserving smoothing of one freehand stroke.
/// Returns null for strokes that look like handwriting or are too small.
/// Works in document units, so results do not depend on zoom.
abstract final class CurveSmoother {
  static const double minLength = 150;
  static const double minDiagonal = 70;

  static const int _maxInflections = 2;
  static const double _inflectionThreshold = 0.6; // radians
  static const double _cornerAngle = 55 * math.pi / 180;
  static const int _passes = 3;
  static const int _subdivisions = 4;

  static List<StrokePoint>? smooth(List<StrokePoint> input) {
    final pts = _dedupe(input);
    if (pts.length < 8) return null;
    final length = _pathLength(pts);
    if (length < minLength || _diagonal(pts) < minDiagonal) return null;

    final samples = _resample(pts, math.max(4.0, length / 90));
    if (samples.length < 8) return null;
    if (_inflections(_relax(samples)) > _maxInflections) return null;

    final cuts = _corners(samples);
    final out = <StrokePoint>[];
    var start = 0;
    for (final end in [...cuts, samples.length - 1]) {
      // A corner is the last point of one run and the first of the next, so
      // it is written twice and InkRenderer keeps it sharp.
      out.addAll(_spline(_relax(samples.sublist(start, end + 1))));
      start = end;
    }
    return out;
  }

  // ---- Analysis ----

  /// Number of times the curve changes turning direction.
  static int _inflections(List<StrokePoint> s) {
    var theta = 0.0, hi = 0.0, lo = 0.0, dir = 0, count = 0;
    for (var i = 1; i < s.length - 1; i++) {
      final a = math.atan2(s[i].y - s[i - 1].y, s[i].x - s[i - 1].x);
      final b = math.atan2(s[i + 1].y - s[i].y, s[i + 1].x - s[i].x);
      theta += _wrap(b - a);
      if (theta > hi) hi = theta;
      if (theta < lo) lo = theta;
      if (dir == 0) {
        if (theta - lo > _inflectionThreshold) {
          dir = 1;
          hi = theta;
        } else if (hi - theta > _inflectionThreshold) {
          dir = -1;
          lo = theta;
        }
      } else if (dir == 1) {
        if (hi - theta > _inflectionThreshold) {
          dir = -1;
          lo = theta;
          count++;
        }
      } else if (theta - lo > _inflectionThreshold) {
        dir = 1;
        hi = theta;
        count++;
      }
    }
    return count;
  }

  /// Indexes of sharp corners (local maxima of the turning angle).
  static List<int> _corners(List<StrokePoint> s) {
    final angles = List<double>.filled(s.length, 0);
    for (var i = 2; i < s.length - 2; i++) {
      final a = math.atan2(s[i].y - s[i - 2].y, s[i].x - s[i - 2].x);
      final b = math.atan2(s[i + 2].y - s[i].y, s[i + 2].x - s[i].x);
      angles[i] = _wrap(b - a).abs();
    }
    final cuts = <int>[];
    for (var i = 2; i < s.length - 2; i++) {
      if (angles[i] < _cornerAngle) continue;
      var peak = true;
      for (var j = i - 2; j <= i + 2; j++) {
        if (angles[j] > angles[i]) peak = false;
      }
      if (peak && (cuts.isEmpty || i - cuts.last > 2)) cuts.add(i);
    }
    return cuts;
  }

  // ---- Smoothing ----

  /// 1-2-1 smoothing; the first and last point never move.
  static List<StrokePoint> _relax(List<StrokePoint> run) {
    if (run.length < 3) return run;
    var cur = run;
    for (var pass = 0; pass < _passes; pass++) {
      final next = List<StrokePoint>.of(cur);
      for (var i = 1; i < cur.length - 1; i++) {
        next[i] = StrokePoint(
          x: 0.25 * cur[i - 1].x + 0.5 * cur[i].x + 0.25 * cur[i + 1].x,
          y: 0.25 * cur[i - 1].y + 0.5 * cur[i].y + 0.25 * cur[i + 1].y,
          pressure: cur[i].pressure,
          timestampMs: cur[i].timestampMs,
        );
      }
      cur = next;
    }
    return cur;
  }

  /// Uniform Catmull-Rom through evenly spaced points: passes through every
  /// input point and cannot overshoot noticeably at this spacing.
  static List<StrokePoint> _spline(List<StrokePoint> r) {
    final out = <StrokePoint>[r.first];
    for (var i = 0; i < r.length - 1; i++) {
      final p0 = r[math.max(i - 1, 0)];
      final p1 = r[i];
      final p2 = r[i + 1];
      final p3 = r[math.min(i + 2, r.length - 1)];
      for (var k = 1; k <= _subdivisions; k++) {
        out.add(
          k == _subdivisions
              ? p2
              : _catmullRom(p0, p1, p2, p3, k / _subdivisions),
        );
      }
    }
    return out;
  }

  static StrokePoint _catmullRom(
    StrokePoint p0,
    StrokePoint p1,
    StrokePoint p2,
    StrokePoint p3,
    double t,
  ) {
    double axis(double a, double b, double c, double d) =>
        0.5 *
        ((2 * b) +
            (-a + c) * t +
            (2 * a - 5 * b + 4 * c - d) * t * t +
            (-a + 3 * b - 3 * c + d) * t * t * t);
    return StrokePoint(
      x: axis(p0.x, p1.x, p2.x, p3.x),
      y: axis(p0.y, p1.y, p2.y, p3.y),
      pressure: p1.pressure + (p2.pressure - p1.pressure) * t,
      timestampMs: (p1.timestampMs + (p2.timestampMs - p1.timestampMs) * t)
          .round(),
    );
  }

  // ---- Helpers ----

  static List<StrokePoint> _resample(List<StrokePoint> p, double step) {
    final out = <StrokePoint>[p.first];
    var carry = step;
    for (var i = 1; i < p.length; i++) {
      final a = p[i - 1];
      final b = p[i];
      final seg = _dist(a, b);
      if (seg == 0) continue;
      var pos = 0.0;
      while (seg - pos >= carry) {
        pos += carry;
        out.add(_lerp(a, b, pos / seg));
        carry = step;
      }
      carry -= seg - pos;
    }
    if (out.length > 1 && _dist(out.last, p.last) < step * 0.5) {
      out[out.length - 1] = p.last;
    } else {
      out.add(p.last);
    }
    return out;
  }

  static StrokePoint _lerp(StrokePoint a, StrokePoint b, double t) =>
      StrokePoint(
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        pressure: a.pressure + (b.pressure - a.pressure) * t,
        timestampMs: (a.timestampMs + (b.timestampMs - a.timestampMs) * t)
            .round(),
      );

  static List<StrokePoint> _dedupe(List<StrokePoint> input) {
    final out = <StrokePoint>[];
    for (final p in input) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      if (out.isNotEmpty && _dist(out.last, p) < 0.5) continue;
      out.add(p);
    }
    return out;
  }

  static double _pathLength(List<StrokePoint> p) {
    var sum = 0.0;
    for (var i = 1; i < p.length; i++) {
      sum += _dist(p[i - 1], p[i]);
    }
    return sum;
  }

  static double _diagonal(List<StrokePoint> p) {
    var l = p.first.x, r = l, t = p.first.y, b = t;
    for (final q in p) {
      l = math.min(l, q.x);
      r = math.max(r, q.x);
      t = math.min(t, q.y);
      b = math.max(b, q.y);
    }
    return math.sqrt((r - l) * (r - l) + (b - t) * (b - t));
  }

  static double _dist(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _wrap(double a) {
    var r = a;
    while (r > math.pi) {
      r -= 2 * math.pi;
    }
    while (r < -math.pi) {
      r += 2 * math.pi;
    }
    return r;
  }
}