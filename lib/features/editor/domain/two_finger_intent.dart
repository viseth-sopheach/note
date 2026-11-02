import 'dart:math' as math;

enum TwoFingerIntent { undecided, scroll, zoom }

/// Decides whether a two-finger gesture is a scroll or a pinch.
/// Decided once per gesture, then locked. No Flutter imports.
final class TwoFingerIntentClassifier {
  TwoFingerIntentClassifier({
    this.touchSlop = 10,
    this.panSlop = 10,
    this.scaleSlop = 0.04,
    this.zoomBias = 1.5,
  });

  /// Movement (px) needed before a touch gesture is classified.
  final double touchSlop;

  /// Touchpad pan distance (px) needed to classify as scroll.
  final double panSlop;

  /// Touchpad scale deviation needed to classify as zoom.
  final double scaleSlop;

  /// Spread change must exceed focal movement by this factor to count as zoom.
  final double zoomBias;

  TwoFingerIntent _intent = TwoFingerIntent.undecided;
  double _startFx = 0, _startFy = 0, _startSpread = 0;

  TwoFingerIntent get intent => _intent;

  void reset() => _intent = TwoFingerIntent.undecided;

  void beginTouch({
    required double ax,
    required double ay,
    required double bx,
    required double by,
  }) {
    _intent = TwoFingerIntent.undecided;
    _startFx = (ax + bx) / 2;
    _startFy = (ay + by) / 2;
    _startSpread = _dist(ax, ay, bx, by);
  }

  TwoFingerIntent updateTouch({
    required double ax,
    required double ay,
    required double bx,
    required double by,
  }) {
    if (_intent != TwoFingerIntent.undecided) return _intent;
    final focal = _dist((ax + bx) / 2, (ay + by) / 2, _startFx, _startFy);
    final spread = (_dist(ax, ay, bx, by) - _startSpread).abs();
    if (math.max(focal, spread) < touchSlop) return _intent;
    return _intent = spread > focal * zoomBias
        ? TwoFingerIntent.zoom
        : TwoFingerIntent.scroll;
  }

  /// [panX]/[panY] and [scale] are cumulative since the gesture started.
  TwoFingerIntent updatePanZoom({
    required double panX,
    required double panY,
    required double scale,
  }) {
    if (_intent != TwoFingerIntent.undecided) return _intent;
    if ((scale - 1).abs() >= scaleSlop) return _intent = TwoFingerIntent.zoom;
    if (math.sqrt(panX * panX + panY * panY) >= panSlop) {
      return _intent = TwoFingerIntent.scroll;
    }
    return _intent;
  }

  static double _dist(double x0, double y0, double x1, double y1) {
    final dx = x1 - x0, dy = y1 - y0;
    return math.sqrt(dx * dx + dy * dy);
  }
}