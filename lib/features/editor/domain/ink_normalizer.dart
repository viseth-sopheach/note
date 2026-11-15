import 'dart:math' as math;

import 'stroke.dart';

typedef InkPoint = ({double x, double y, int t});

/// Converts strokes into recognizer input: origin at (0, 0), uniform scale
/// into a sane range, and strictly increasing timestamps with a gap between
/// strokes. No Flutter imports.
abstract final class InkNormalizer {
  static const int strokeGapMs = 120;
  static const int fallbackStepMs = 8;
  static const double minExtent = 120;
  static const double maxExtent = 2000;
  static const double maxUpscale = 6;

  static List<List<InkPoint>> normalize(List<Stroke> strokes) {
    final usable = <List<({double x, double y, int t})>>[];
    for (final s in strokes) {
      final pts = [
        for (final p in s.points)
          if (p.x.isFinite && p.y.isFinite) (x: p.x, y: p.y, t: p.timestampMs),
      ];
      if (pts.isNotEmpty) usable.add(pts);
    }
    if (usable.isEmpty) return const [];

    var left = usable.first.first.x, right = left;
    var top = usable.first.first.y, bottom = top;
    for (final pts in usable) {
      for (final p in pts) {
        left = math.min(left, p.x);
        right = math.max(right, p.x);
        top = math.min(top, p.y);
        bottom = math.max(bottom, p.y);
      }
    }
    final extent = math.max(right - left, bottom - top);
    var scale = 1.0;
    if (extent > maxExtent) {
      scale = maxExtent / extent;
    } else if (extent > 0 && extent < minExtent) {
      scale = math.min(maxUpscale, minExtent / extent);
    }

    final out = <List<InkPoint>>[];
    var base = 0;
    var last = -1;
    for (final pts in usable) {
      final first = pts.first.t;
      final timed = pts.last.t > first;
      final stroke = <InkPoint>[];
      for (var i = 0; i < pts.length; i++) {
        final raw = base + (timed ? pts[i].t - first : i * fallbackStepMs);
        final t = math.max(raw, last + 1);
        last = t;
        stroke.add((
          x: (pts[i].x - left) * scale,
          y: (pts[i].y - top) * scale,
          t: t,
        ));
      }
      base = last + strokeGapMs;
      out.add(stroke);
    }
    return out;
  }
}
