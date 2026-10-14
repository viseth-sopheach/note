import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/command_history.dart';
import '../domain/drawing_command.dart';
import '../domain/stroke.dart';
import '../domain/stroke_point.dart';
import '../domain/stroke_recorder.dart';
import '../domain/stroke_tool.dart';

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Holds the strokes of the open page and the stroke being drawn.
///
/// Listen to this object for committed changes (stroke added, drawing
/// started or ended). Listen to [live] for every accepted point.
class DrawingController extends ChangeNotifier {
  DrawingController({String Function()? idGenerator, double minDistance = 0.5})
      : _newId = idGenerator ?? (() => const Uuid().v4()),
        _recorder = StrokeRecorder(minDistance: minDistance);

  final String Function() _newId;
  final StrokeRecorder _recorder;
  final _Signal _live = _Signal();
  final List<Stroke> _strokes = [];
  final CommandHistory _history = CommandHistory();

  StrokeTool _tool = StrokeTool.pen;
  int _colorValue = 0xFF1B1B1F;
  double _width = 2;

  StrokeTool get tool => _tool;
  int get colorValue => _colorValue;
  double get width => _width;

  /// Tool, color and width cannot change while a stroke is being drawn.
  void selectTool(StrokeTool tool) {
    if (isDrawing || tool == _tool) return;
    _tool = tool;
    _width = tool == StrokeTool.pen ? 2 : 3;
    notifyListeners();
  }

  void selectColor(int colorValue) {
    if (isDrawing || colorValue == _colorValue) return;
    _colorValue = colorValue;
    notifyListeners();
  }

  void selectWidth(double width) {
    if (isDrawing || width == _width) return;
    _width = width;
    notifyListeners();
  }

  int? _activePointer;
  int _originMs = 0;

  Listenable get live => _live;

  bool get isDrawing => _activePointer != null;

  List<Stroke> get strokes => UnmodifiableListView(_strokes);

  bool get canUndo => !isDrawing && _history.canUndo;

  bool get canRedo => !isDrawing && _history.canRedo;

  void undo() {
    if (!canUndo) return;
    _history.undo(_strokes);
    _revision++;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _history.redo(_strokes);
    _revision++;
    notifyListeners();
  }

  int _revision = 0;

  /// Increases every time the finished strokes change through drawing,
  /// undo or redo. Loading strokes with [replaceStrokes] does not change it.
  int get revision => _revision;

  /// Replaces all strokes, for example after loading a page.
  void replaceStrokes(List<Stroke> strokes) {
    if (isDrawing) return;
    _strokes
      ..clear()
      ..addAll(strokes);
    _history.clear();
    notifyListeners();
  }

  /// Points of the stroke being drawn; empty when idle.
  List<StrokePoint> get livePoints => _recorder.points;

  bool beginStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (isDrawing) return false;
    _activePointer = pointer;
    _originMs = timeMs;
    _recorder.begin(
      id: _newId(),
      tool: _tool,
      colorValue: _colorValue,
      width: _width,
      first: StrokePoint(x: x, y: y, pressure: pressure, timestampMs: 0),
    );
    notifyListeners();
    _live.ping();
    return true;
  }

  void extendStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (pointer != _activePointer) return;
    final kept = _recorder.add(
      StrokePoint(
        x: x,
        y: y,
        pressure: pressure,
        timestampMs: timeMs - _originMs,
      ),
    );
    if (kept) _live.ping();
  }

  void endStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (pointer != _activePointer) return;
    _recorder.add(
      StrokePoint(
        x: x,
        y: y,
        pressure: pressure,
        timestampMs: timeMs - _originMs,
      ),
    );
    _history.execute(AddStrokeCommand(_recorder.end()), _strokes);
    _revision++;
    _activePointer = null;
    notifyListeners();
    _live.ping();
  }

  void cancelStroke(int pointer) {
    if (pointer != _activePointer) return;
    _recorder.cancel();
    _activePointer = null;
    notifyListeners();
    _live.ping();
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }
}