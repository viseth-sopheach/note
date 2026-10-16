import 'stroke_point.dart';
import 'stroke_tool.dart';

/// One continuous pen or highlighter line. Immutable.
final class Stroke {
  Stroke({
    required this.id,
    required this.tool,
    required this.colorValue,
    required this.width,
    required List<StrokePoint> points,
  }) : points = List<StrokePoint>.unmodifiable(points);

  final String id;
  final StrokeTool tool;

  /// ARGB color value, same format as Color.toARGB32().
  final int colorValue;

  /// Base width in document units.
  final double width;

  final List<StrokePoint> points;

  bool get isEmpty => points.isEmpty;

  Stroke copyWith({
    StrokeTool? tool,
    int? colorValue,
    double? width,
    List<StrokePoint>? points,
  }) => Stroke(
    id: id,
    tool: tool ?? this.tool,
    colorValue: colorValue ?? this.colorValue,
    width: width ?? this.width,
    points: points ?? this.points,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Stroke) return false;
    if (other.id != id ||
        other.tool != tool ||
        other.colorValue != colorValue ||
        other.width != width ||
        other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (other.points[i] != points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, tool, colorValue, width, Object.hashAll(points));
}
