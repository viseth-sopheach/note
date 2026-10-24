import 'curve_smoother.dart';
import 'shape_recognizer.dart';
import 'stroke_point.dart';

/// Decides what a finished stroke should become. No Flutter imports.
abstract final class SmartStroke {
  static const double _minPath = 60;

  /// Cheap check so tiny strokes (handwriting dots, ticks) never start a timer.
  static bool isCandidate(List<StrokePoint> p) {
    if (p.length < 6) return false;
    var length = 0.0;
    for (var i = 1; i < p.length; i++) {
      final dx = p[i].x - p[i - 1].x;
      final dy = p[i].y - p[i - 1].y;
      length += (dx * dx + dy * dy) == 0 ? 0 : _hyp(dx, dy);
    }
    return length >= _minPath;
  }

  /// Clean shape, smoothed curve, or null to keep the stroke untouched.
  static List<StrokePoint>? refine(List<StrokePoint> points) {
    if (!isCandidate(points)) return null;
    return ShapeRecognizer.recognize(points)?.points ??
        CurveSmoother.smooth(points);
  }

  static double _hyp(double dx, double dy) =>
      (dx * dx + dy * dy) <= 0 ? 0 : _sqrt(dx * dx + dy * dy);

  static double _sqrt(double v) {
    // Avoids importing dart:math just for one call site.
    var x = v;
    var y = 1.0;
    for (var i = 0; i < 40 && (x - y).abs() > 1e-9 * x; i++) {
      x = (x + y) / 2;
      y = v / x;
    }
    return x;
  }
}