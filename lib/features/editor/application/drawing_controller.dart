import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:uuid/uuid.dart';

import '../domain/command_history.dart';
import '../domain/drawing_command.dart';
import '../domain/shape_geometry.dart';
import '../domain/stroke.dart';
import '../domain/stroke_hit_test.dart';
import '../domain/stroke_point.dart';
import '../domain/stroke_recorder.dart';
import '../domain/stroke_selection.dart';
import '../domain/stroke_tool.dart';
import 'tool_settings.dart';

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}

enum _Mode { none, draw, erase, lasso, move, shape }

/// Holds the strokes of one page, the stroke being drawn and the current
/// selection. Tool, color and width come from [settings], which can be
/// shared by the controllers of several pages.
///
/// Coordinates are relative to the paper corner and may be negative or
/// larger than the page (drawing outside the paper).
///
/// Listen to this object for committed changes (stroke added, erased,
/// moved, selection or tool changed). Listen to [live] for every accepted
/// point.
class DrawingController extends ChangeNotifier {
  DrawingController({
    String Function()? idGenerator,
    double minDistance = 0.5,
    ToolSettings? settings,
  })  : _newId = idGenerator ?? (() => const Uuid().v4()),
        _recorder = StrokeRecorder(minDistance: minDistance),
        _ownsSettings = settings == null,
        _settings = settings ?? ToolSettings() {
    _seenTool = _settings.tool;
    _settings.addListener(_onSettingsChanged);
  }

  /// Eraser radius in document units.
  static const double eraserRadius = 10;

  /// Extra area around the selection that still grabs it, in document units.
  static const double _grabSlop = 8;

  /// A stroke that starts this close to a ruler edge snaps onto it.
  static const double snapDistance = 24;

  /// Returns ruler edges in this page's coordinates, or an empty list.
  List<Segment> Function()? snapSegments;

  final String Function() _newId;
  final StrokeRecorder _recorder;
  final ToolSettings _settings;
  final bool _ownsSettings;
  final _Signal _live = _Signal();
  final List<Stroke> _strokes = [];
  final CommandHistory _history = CommandHistory();

  late StrokeTool _seenTool;

  _Mode _mode = _Mode.none;
  RemoveStrokesCommand? _erase;
  double _lastX = 0;
  double _lastY = 0;

  final List<Vertex> _lasso = [];
  final Set<String> _selected = {};
  double _moveFromX = 0;
  double _moveFromY = 0;
  double _dx = 0;
  double _dy = 0;

  final List<StrokePoint> _shape = [];
  double _shapeX0 = 0;
  double _shapeY0 = 0;
  double _shapeX1 = 0;
  double _shapeY1 = 0;
  Segment? _snap;

  int? _activePointer;
  int _originMs = 0;
  int _revision = 0;

  ToolSettings get settings => _settings;
  StrokeTool get tool => _settings.tool;
  int get colorValue => _settings.colorValue;
  double get width => _settings.width;

  void _onSettingsChanged() {
    if (_settings.tool != _seenTool) {
      _seenTool = _settings.tool;
      _selected.clear();
    }
    notifyListeners();
    _live.ping();
  }

  /// Tool, color and width cannot change while a stroke is being drawn.
  void selectTool(StrokeTool tool) {
    if (isDrawing) return;
    _settings.selectTool(tool);
  }

  void selectColor(int colorValue) {
    if (isDrawing) return;
    _settings.selectColor(colorValue);
  }

  void selectWidth(double width) {
    if (isDrawing) return;
    _settings.selectWidth(width);
  }

  Listenable get live => _live;

  bool get isDrawing => _activePointer != null;

  List<Stroke> get strokes => UnmodifiableListView(_strokes);

  bool get canUndo => !isDrawing && _history.canUndo;

  bool get canRedo => !isDrawing && _history.canRedo;

  /// Increases every time the finished strokes change through drawing,
  /// erasing, moving, deleting, undo or redo. Loading strokes with
  /// [replaceStrokes] does not change it.
  int get revision => _revision;

  // ---- Selection state ----

  Set<String> get selectedIds => UnmodifiableSetView(_selected);

  bool get hasSelection => _selected.isNotEmpty;

  bool get isMovingSelection => _mode == _Mode.move;

  /// Lasso path being drawn; empty when idle.
  List<Vertex> get lasso => UnmodifiableListView(_lasso);

  double get selectionDx => _dx;

  double get selectionDy => _dy;

  Iterable<Stroke> get selectedStrokes =>
      _strokes.where((s) => _selected.contains(s.id));

  /// Bounds of the selection including the move in progress, or null.
  Bounds? get selectionBounds {
    if (_selected.isEmpty) return null;
    final b = StrokeSelection.boundsOf(selectedStrokes);
    if (b == null) return null;
    return (
      left: b.left + _dx,
      top: b.top + _dy,
      right: b.right + _dx,
      bottom: b.bottom + _dy,
    );
  }

  void clearSelection() {
    if (isDrawing || _selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
    _live.ping();
  }

  /// Deletes the selected strokes as one undoable step.
  void deleteSelection() {
    if (isDrawing || _selected.isEmpty) return;
    final command = RemoveStrokesCommand();
    for (var i = _strokes.length - 1; i >= 0; i--) {
      if (_selected.contains(_strokes[i].id)) command.take(_strokes, i);
    }
    _selected.clear();
    if (!command.isEmpty) {
      _history.record(command);
      _revision++;
    }
    notifyListeners();
    _live.ping();
  }

  // ---- History ----

  void undo() {
    if (!canUndo) return;
    _selected.clear();
    _history.undo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  void redo() {
    if (!canRedo) return;
    _selected.clear();
    _history.redo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  /// Replaces all strokes, for example after loading a page.
  void replaceStrokes(List<Stroke> strokes) {
    if (isDrawing) return;
    _strokes
      ..clear()
      ..addAll(strokes);
    _selected.clear();
    _history.clear();
    notifyListeners();
    _live.ping();
  }

  /// Points of the stroke or shape being drawn; empty when idle, erasing
  /// or selecting.
  List<StrokePoint> get livePoints =>
      _mode == _Mode.shape ? UnmodifiableListView(_shape) : _recorder.points;

  // ---- Ruler snapping ----

  Segment? _findSnap(double x, double y) {
    final provider = snapSegments;
    if (provider == null) return null;
    Segment? best;
    var bestDistance = snapDistance;
    for (final s in provider()) {
      final d = ShapeGeometry.distanceToSegment(s, x, y);
      if (d <= bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  ({double x, double y}) _snapPoint(double x, double y) {
    final s = _snap;
    return s == null ? (x: x, y: y) : ShapeGeometry.project(s, x, y);
  }

  // ---- Pointer input ----

  bool beginStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (isDrawing) return false;
    _activePointer = pointer;

    switch (_settings.tool) {
      case StrokeTool.eraser:
        _mode = _Mode.erase;
        _erase = RemoveStrokesCommand();
        _lastX = x;
        _lastY = y;
        _eraseTo(x, y);
        notifyListeners();
        return true;

      case StrokeTool.select:
        _beginSelect(x, y);
        return true;

      case StrokeTool.pen:
      case StrokeTool.highlighter:
        _mode = _Mode.draw;
        _originMs = timeMs;
        _snap = _findSnap(x, y);
        final start = _snapPoint(x, y);
        _recorder.begin(
          id: _newId(),
          tool: _settings.tool,
          colorValue: _settings.colorValue,
          width: _settings.width,
          first: StrokePoint(
            x: start.x,
            y: start.y,
            pressure: pressure,
            timestampMs: 0,
          ),
        );
        notifyListeners();
        _live.ping();
        return true;

      case StrokeTool.line:
        return _beginShape(x, y, snapToRuler: true);

      case StrokeTool.rectangle:
      case StrokeTool.ellipse:
      case StrokeTool.triangle:
        return _beginShape(x, y, snapToRuler: false);
    }
  }

  bool _beginShape(double x, double y, {required bool snapToRuler}) {
    _mode = _Mode.shape;
    _snap = snapToRuler ? _findSnap(x, y) : null;
    final start = _snapPoint(x, y);
    _shapeX0 = start.x;
    _shapeY0 = start.y;
    _updateShape(x, y);
    notifyListeners();
    _live.ping();
    return true;
  }

  void _updateShape(double x, double y) {
    final end = _snapPoint(x, y);
    _shapeX1 = end.x;
    _shapeY1 = end.y;
    _shape
      ..clear()
      ..addAll(
        ShapeGeometry.build(
          _settings.tool,
          x0: _shapeX0,
          y0: _shapeY0,
          x1: _shapeX1,
          y1: _shapeY1,
          constrain: _snap == null && HardwareKeyboard.instance.isShiftPressed,
        ),
      );
  }

  void extendStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (pointer != _activePointer) return;

    switch (_mode) {
      case _Mode.erase:
        if (_eraseTo(x, y)) notifyListeners();
      case _Mode.lasso:
        final last = _lasso.last;
        final dx = x - last.x;
        final dy = y - last.y;
        if (dx * dx + dy * dy >= 4) {
          _lasso.add((x: x, y: y));
          _live.ping();
        }
      case _Mode.move:
        _dx = x - _moveFromX;
        _dy = y - _moveFromY;
        _live.ping();
      case _Mode.shape:
        _updateShape(x, y);
        _live.ping();
      case _Mode.draw:
        final p = _snapPoint(x, y);
        final kept = _recorder.add(
          StrokePoint(
            x: p.x,
            y: p.y,
            pressure: pressure,
            timestampMs: timeMs - _originMs,
          ),
        );
        if (kept) _live.ping();
      case _Mode.none:
        break;
    }
  }

  void endStroke({
    required int pointer,
    required double x,
    required double y,
    required double pressure,
    required int timeMs,
  }) {
    if (pointer != _activePointer) return;

    switch (_mode) {
      case _Mode.erase:
        final erase = _erase!;
        _eraseTo(x, y);
        if (!erase.isEmpty) {
          _history.record(erase);
          _revision++;
        }
        _erase = null;
        _finish();
        notifyListeners();

      case _Mode.lasso:
        _lasso.add((x: x, y: y));
        _selected
          ..clear()
          ..addAll(StrokeSelection.insideLasso(_strokes, _lasso));
        _lasso.clear();
        _finish();
        notifyListeners();
        _live.ping();

      case _Mode.move:
        final dx = x - _moveFromX;
        final dy = y - _moveFromY;
        final ids = Set<String>.of(_selected);
        _dx = 0;
        _dy = 0;
        _finish();
        if (dx.abs() >= 0.5 || dy.abs() >= 0.5) {
          _history.execute(MoveStrokesCommand(ids, dx, dy), _strokes);
          _revision++;
        }
        notifyListeners();
        _live.ping();

      case _Mode.shape:
        _updateShape(x, y);
        if (ShapeGeometry.isUsable(_shapeX0, _shapeY0, _shapeX1, _shapeY1)) {
          final stroke = Stroke(
            id: _newId(),
            tool: StrokeTool.pen,
            colorValue: _settings.colorValue,
            width: _settings.width,
            points: _shape,
          );
          _history.execute(AddStrokeCommand(stroke), _strokes);
          _revision++;
        }
        _shape.clear();
        _finish();
        notifyListeners();
        _live.ping();

      case _Mode.draw:
        final p = _snapPoint(x, y);
        _recorder.add(
          StrokePoint(
            x: p.x,
            y: p.y,
            pressure: pressure,
            timestampMs: timeMs - _originMs,
          ),
        );
        var stroke = _recorder.end();
        if (_snap != null && stroke.points.length > 2) {
          // Snapped to the ruler: keep only the two ends of the line.
          stroke = stroke.copyWith(
            points: [stroke.points.first, stroke.points.last],
          );
        }
        _history.execute(AddStrokeCommand(stroke), _strokes);
        _revision++;
        _finish();
        notifyListeners();
        _live.ping();

      case _Mode.none:
        break;
    }
  }

  void cancelStroke(int pointer) {
    if (pointer != _activePointer) return;

    switch (_mode) {
      case _Mode.erase:
        _erase!.revert(_strokes);
        _erase = null;
      case _Mode.lasso:
        _lasso.clear();
      case _Mode.move:
        _dx = 0;
        _dy = 0;
      case _Mode.shape:
        _shape.clear();
      case _Mode.draw:
        _recorder.cancel();
      case _Mode.none:
        break;
    }
    _finish();
    notifyListeners();
    _live.ping();
  }

  void _finish() {
    _mode = _Mode.none;
    _activePointer = null;
    _snap = null;
  }

  void _beginSelect(double x, double y) {
    final b = selectionBounds;
    final grabbed = b != null &&
        x >= b.left - _grabSlop &&
        x <= b.right + _grabSlop &&
        y >= b.top - _grabSlop &&
        y <= b.bottom + _grabSlop;

    if (grabbed) {
      _mode = _Mode.move;
      _moveFromX = x;
      _moveFromY = y;
      _dx = 0;
      _dy = 0;
    } else {
      _selected.clear();
      _mode = _Mode.lasso;
      _lasso
        ..clear()
        ..add((x: x, y: y));
    }
    notifyListeners();
    _live.ping();
  }

  /// Erases strokes touched by the path from the last point to (x, y).
  /// Returns true when at least one stroke was removed.
  bool _eraseTo(double x, double y) {
    final erase = _erase!;
    var changed = false;
    for (var i = _strokes.length - 1; i >= 0; i--) {
      if (StrokeHitTest.hitsSegment(
        _strokes[i],
        ax: _lastX,
        ay: _lastY,
        bx: x,
        by: y,
        radius: eraserRadius,
      )) {
        erase.take(_strokes, i);
        changed = true;
      }
    }
    _lastX = x;
    _lastY = y;
    return changed;
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    if (_ownsSettings) _settings.dispose();
    _live.dispose();
    super.dispose();
  }
}