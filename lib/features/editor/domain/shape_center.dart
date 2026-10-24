import 'dart:math' as math;

import 'stroke.dart';
import 'stroke_point.dart';
import 'stroke_selection.dart';
import 'stroke_tool.dart';

/// Center dot of a circle or ellipse. A normal one-point stroke whose id is
/// "<shapeId>:c", so erase, undo, save and export need no special cases.
abstract final class ShapeCenter {
  static const String suffix = ':c';
  static const double minDotWidth = 5;

  static String dotId(String ownerId) => '$ownerId$suffix';
  static bool isDot(Stroke s) => s.id.endsWith(suffix);
  static String ownerOf(String dotId) =>
      dotId.substring(0, dotId.length - suffix.length);

  static Stroke? dotFor(Stroke ellipse) {
    if (ellipse.tool == StrokeTool.highlighter) return null;
    final b = StrokeSelection.pointBoundsOf([ellipse]);
    if (b == null) return null;
    return Stroke(
      id: dotId(ellipse.id),
      tool: StrokeTool.pen,
      colorValue: ellipse.colorValue,
      width: math.max(minDotWidth, ellipse.width * 2.5),
      points: [
        StrokePoint(x: (b.left + b.right) / 2, y: (b.top + b.bottom) / 2),
      ],
    );
  }

  /// [ids] plus each shape's dot and each dot's shape. Always a new set.
  static Set<String> withCompanions(List<Stroke> strokes, Set<String> ids) {
    final all = {...ids};
    final present = {for (final s in strokes) s.id};
    for (final id in ids) {
      if (id.endsWith(suffix)) {
        final owner = ownerOf(id);
        if (present.contains(owner)) all.add(owner);
      } else {
        final dot = dotId(id);
        if (present.contains(dot)) all.add(dot);
      }
    }
    return all;
  }
}