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
    this.alphas,
  });

  final List<InkVertex> left;
  final List<InkVertex> right;
  final InkSample start;
  final InkSample end;

  /// Opacity 0..1 per centre-line sample, or null for fully opaque.
  final List<double>? alphas;
}

/// Pen-on-paper ink geometry. No Flutter imports.
///
/// The centre line is the recorded path: it is never straightened, rotated
/// or reshaped. The width is constant: every stroke is drawn at the user's
/// chosen [Stroke.width], with rounded ends and no taper, wobble, speed or
/// curve modulation. This keeps handwriting exactly as written, matching
/// the "off by default" shape recognition setting.
abstract final class InkGeometry {
  static const double _minHalf = 0.25; // fine Khmer marks never vanish

  /// Stable across runs (String.hashCode is not).
  static int seedFor(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Ink width never varies, so callers can always take the uniform
  /// polyline branch. Kept as a method so the call sites do not change.
  static bool usesVariableWidth(List<StrokePoint> pts) => false;

  /// Returns null when the stroke is too short for an outline.
  static InkOutline? build(
    List<StrokePoint> input,
    double baseWidth, {
    int seed = 0,
  }) {
    final pts = _dedupe(input);
    if (pts.length < 3) return null;
    final half = math.max(_minHalf, baseWidth / 2);
    final samples = [for (final p in pts) (x: p.x, y: p.y, r: half)];
    return offset(samples);
  }

  // ---- Centre line and outline ----

  static InkOutline offset(List<InkSample> c, {List<double>? alphas}) {
    final left = <InkVertex>[];
    final right = <InkVertex>[];
    var tx = 1.0, ty = 0.0;
    for (var j = 0; j < c.length; j++) {
      final a = c[math.max(0, j - 2)];
      final b = c[math.min(c.length - 1, j + 2)];
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
    return InkOutline(
      left: left,
      right: right,
      start: c.first,
      end: c.last,
      alphas: alphas,
    );
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
