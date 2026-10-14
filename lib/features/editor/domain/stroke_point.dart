/// One sampled input point, in document coordinates.
final class StrokePoint {
  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.timestampMs = 0,
  });

  final double x;
  final double y;

  /// Normalized 0.0 to 1.0. Devices without pressure report 1.0.
  final double pressure;

  /// Milliseconds since the stroke started.
  final int timestampMs;

  @override
  bool operator ==(Object other) =>
      other is StrokePoint &&
      other.x == x &&
      other.y == y &&
      other.pressure == pressure &&
      other.timestampMs == timestampMs;

  @override
  int get hashCode => Object.hash(x, y, pressure, timestampMs);

  @override
  String toString() =>
      'StrokePoint($x, $y, p: $pressure, t: $timestampMs)';
}