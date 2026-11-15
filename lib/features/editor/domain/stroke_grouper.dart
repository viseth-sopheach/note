import 'dart:math' as math;

import 'stroke.dart';
import 'stroke_selection.dart';

/// Splits strokes into spatial clusters (one cluster ~ one word or line).
/// Keeps multi-stroke characters, vowels and subscripts together.
/// No Flutter imports.
abstract final class StrokeGrouper {
  static const double minReference = 12;
  static const double sideGapFactor = 1.2;
  static const double stackedGapFactor = 0.45;
  static const double lineGapFactor = 0.25;

  static List<List<Stroke>> group(List<Stroke> strokes) {
    final kept = <Stroke>[];
    final boxes = <Bounds>[];
    for (final s in strokes) {
      final b = StrokeSelection.pointBoundsOf([s]);
      if (b == null) continue;
      kept.add(s);
      boxes.add(b);
    }
    if (kept.isEmpty) return const [];

    final ref = _reference(boxes);
    final parent = List<int>.generate(kept.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (var i = 0; i < kept.length; i++) {
      for (var j = i + 1; j < kept.length; j++) {
        if (_linked(boxes[i], boxes[j], ref)) {
          final a = find(i), b = find(j);
          if (a != b) parent[math.max(a, b)] = math.min(a, b);
        }
      }
    }

    final groups = <int, List<Stroke>>{};
    for (var i = 0; i < kept.length; i++) {
      (groups[find(i)] ??= <Stroke>[]).add(kept[i]);
    }
    return groups.values.toList();
  }

  static double _reference(List<Bounds> boxes) {
    final heights = [
      for (final b in boxes)
        if (b.bottom - b.top > 4) b.bottom - b.top,
    ]..sort();
    if (heights.isEmpty) return minReference;
    return math.max(minReference, heights[heights.length ~/ 2]);
  }

  static bool _linked(Bounds a, Bounds b, double ref) {
    final dx = math.max(
      0.0,
      math.max(a.left, b.left) - math.min(a.right, b.right),
    );
    final dy = math.max(
      0.0,
      math.max(a.top, b.top) - math.min(a.bottom, b.bottom),
    );
    if (dx == 0) return dy <= ref * stackedGapFactor;
    return dx <= ref * sideGapFactor && dy <= ref * lineGapFactor;
  }
}
