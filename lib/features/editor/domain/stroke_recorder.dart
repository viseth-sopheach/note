import 'dart:collection';

import 'stroke.dart';
import 'stroke_point.dart';
import 'stroke_tool.dart';

/// Collects points for one stroke at a time. No Flutter imports.
final class StrokeRecorder {
  StrokeRecorder({this.minDistance = 1.5});

  /// Points closer than this to the previous point (document units) are skipped.
  final double minDistance;

  final List<StrokePoint> _points = [];
  String? _id;
  StrokeTool _tool = StrokeTool.pen;
  int _colorValue = 0;
  double _width = 0;

  /// Id of the stroke currently being recorded, or null when idle.
  /// Stable for the whole life of the live stroke, so it can be used as a
  /// cache key by the live ink renderer.
  String? get id => _id;

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
  bool add(StrokePoint point, {bool force = false}) {
    if (!isActive) throw StateError('No stroke is being recorded.');
    final last = _points.last;
    final dx = point.x - last.x;
    final dy = point.y - last.y;
    final sq = dx * dx + dy * dy;
    if (sq == 0 || (!force && sq < minDistance * minDistance)) return false;
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
