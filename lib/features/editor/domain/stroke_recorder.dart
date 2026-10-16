import 'dart:collection';

import 'stroke.dart';
import 'stroke_point.dart';
import 'stroke_tool.dart';

/// Collects points for one stroke at a time. No Flutter imports.
final class StrokeRecorder {
  StrokeRecorder({this.minDistance = 0.5});

  /// Points closer than this to the previous point (document units) are skipped.
  final double minDistance;

  final List<StrokePoint> _points = [];
  String? _id;
  StrokeTool _tool = StrokeTool.pen;
  int _colorValue = 0;
  double _width = 0;

  bool get isActive => _id != null;

  List<StrokePoint> get points => UnmodifiableListView(_points);

  void begin({
    required String id,
    required StrokeTool tool,
    required int colorValue,
    required double width,
    required StrokePoint first,
  }) {
    if (isActive) throw StateError('A stroke is already being recorded.');
    _id = id;
    _tool = tool;
    _colorValue = colorValue;
    _width = width;
    _points
      ..clear()
      ..add(first);
  }

  /// Returns true when the point was kept.
  bool add(StrokePoint point) {
    if (!isActive) throw StateError('No stroke is being recorded.');
    final last = _points.last;
    final dx = point.x - last.x;
    final dy = point.y - last.y;
    if (dx * dx + dy * dy < minDistance * minDistance) return false;
    _points.add(point);
    return true;
  }

  Stroke end() {
    final id = _id;
    if (id == null) throw StateError('No stroke is being recorded.');
    final stroke = Stroke(
      id: id,
      tool: _tool,
      colorValue: _colorValue,
      width: _width,
      points: _points,
    );
    cancel();
    return stroke;
  }

  void cancel() {
    _id = null;
    _points.clear();
  }
}
