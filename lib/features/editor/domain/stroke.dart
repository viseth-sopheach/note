import 'shape_recognizer.dart' show ShapeKind;
import 'stroke_point.dart';
import 'stroke_tool.dart';

/// One continuous pen or highlighter line. Immutable.
///
/// [shape] is non-null only for the four selectable basic shapes
/// (line, rectangle, ellipse, triangle). Freehand strokes keep it null.
final class Stroke {
  Stroke({
    required this.id,
    required this.tool,
    required this.colorValue,
    required this.width,
    required List<StrokePoint> points,
    this.shape,
  }) : points = List<StrokePoint>.unmodifiable(points);

  static const Object _keep = Object();

  final String id;
  final StrokeTool tool;

  /// ARGB color value, same format as Color.toARGB32().
  final int colorValue;

  /// Base width in document units.
  final double width;

  final List<StrokePoint> points;

  /// Only line, rectangle, ellipse or triangle, otherwise null.
  final ShapeKind? shape;

  bool get isEmpty => points.isEmpty;

  /// Pass `shape: null` to clear the shape; omit it to keep the current one.
  Stroke copyWith({
    StrokeTool? tool,
    int? colorValue,
    double? width,
    List<StrokePoint>? points,
    Object? shape = _keep,
  }) => Stroke(
    id: id,
    tool: tool ?? this.tool,
    colorValue: colorValue ?? this.colorValue,
    width: width ?? this.width,
    points: points ?? this.points,
    shape: identical(shape, _keep) ? this.shape : shape as ShapeKind?,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Stroke) return false;
    if (other.id != id ||
        other.tool != tool ||
        other.colorValue != colorValue ||
        other.width != width ||
        other.shape != shape ||
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
      Object.hash(id, tool, colorValue, width, Object.hashAll(points), shape);
}
