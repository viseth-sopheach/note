import 'dart:math' as math;

/// Speed-adaptive low-pass filter for freehand points. No Flutter imports.
///
/// Slow movement is smoothed more (alpha [slowAlpha]) to remove hand and
/// digitizer jitter. Fast movement follows the pointer closely
/// (alpha [fastAlpha]) so there is little lag.
final class PenFilter {
  PenFilter({
    this.slowAlpha = 0.35,
    this.fastAlpha = 0.8,
    this.slowSpeed = 0.15, // document units per ms
    this.fastSpeed = 1.5,
  });

  final double slowAlpha;
  final double fastAlpha;
  final double slowSpeed;
  final double fastSpeed;

  double _x = 0, _y = 0, _rx = 0, _ry = 0;
  int _t = 0;

  void begin(double x, double y, int timeMs) {
    _x = _rx = x;
    _y = _ry = y;
    _t = timeMs;
  }

  ({double x, double y}) apply(double x, double y, int timeMs) {
    final dt = math.max(1, timeMs - _t);
    final dx = x - _rx, dy = y - _ry;
    final speed = math.sqrt(dx * dx + dy * dy) / dt;
    final k = ((speed - slowSpeed) / (fastSpeed - slowSpeed))
        .clamp(0.0, 1.0)
        .toDouble();
    final alpha = slowAlpha + (fastAlpha - slowAlpha) * k;
    _x += (x - _x) * alpha;
    _y += (y - _y) * alpha;
    _rx = x;
    _ry = y;
    _t = timeMs;
    return (x: _x, y: _y);
  }
}