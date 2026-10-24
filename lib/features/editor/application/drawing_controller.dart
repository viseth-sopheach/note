import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:uuid/uuid.dart';

import '../domain/command_history.dart';
import '../domain/drawing_command.dart';
import '../domain/selection_handle.dart';
import '../domain/shape_geometry.dart';
import '../domain/shape_recognizer.dart';
import '../domain/smart_stroke.dart';
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

enum _Mode { none, draw, erase, lasso, move, shape, resize }

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
    int undoLimit = 200,
    this.holdDuration = const Duration(milliseconds: 1000),
    this.refineDelay = const Duration(milliseconds: 700),
  }) : _newId = idGenerator ?? (() => const Uuid().v4()),
       _recorder = StrokeRecorder(minDistance: minDistance),
       _history = CommandHistory(limit: undoLimit),
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

  /// Pointer jitter below this distance (document units) still counts as
  /// holding still.
  static const double holdTolerance = 3;

  static const double framePad = 8;
  static const double handleHitPx = 18;
  static const double tapSlopPx = 6;
  static const double minShapeSide = 12;

  /// How long the pointer must rest at the end of a stroke to snap it.
  final Duration holdDuration;

  /// Pause after a stroke ends before it is recognized or smoothed.
  final Duration refineDelay;

  /// Called once when a held stroke was turned into a clean shape.
  void Function()? onShapeRecognized;

  /// Returns ruler edges in this page's coordinates, or an empty list.
  List<Segment> Function()? snapSegments;

  /// Current zoom, set by the editor so handles keep a constant screen size.
  double Function()? viewScale;

  final String Function() _newId;
  final StrokeRecorder _recorder;
  final ToolSettings _settings;
  final bool _ownsSettings;
  final _Signal _live = _Signal();
  final List<Stroke> _strokes = [];
  final CommandHistory _history;

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

  // Hold-to-snap state of the stroke being drawn.
  Timer? _holdTimer;
  bool _holdArmed = false;
  double _holdX = 0;
  double _holdY = 0;
  int _holdCount = 0;
  RecognizedShape? _recognized;

  Timer? _refineTimer;
  SelectionHandle? _handle;
  Bounds? _resizeBox;
  double _pressX = 0, _pressY = 0, _downX = 0, _downY = 0;
  double _rsx = 1, _rsy = 1, _rax = 0, _ray = 0;
  bool _deselectedOnDown = false;

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

  /// Shape the held stroke was snapped to, or null while nothing snapped.
  ShapeKind? get recognizedShape => _recognized?.kind;

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

  bool get isResizingSelection => _mode == _Mode.resize;

  bool get isTransformingSelection =>
      _mode == _Mode.move || _mode == _Mode.resize;

  double get _scale => (viewScale?.call() ?? 1.0).clamp(0.05, 20.0).toDouble();

  void refreshView() => _live.ping();

  /// Live bounds of the selected points (follows move and resize), or null.
  Bounds? get selectionFrame {
    if (_selected.isEmpty) return null;
    if (_mode == _Mode.resize) {
      final b = _resizeBox;
      if (b == null) return null;
      return (
        left: _rax + (b.left - _rax) * _rsx,
        top: _ray + (b.top - _ray) * _rsy,
        right: _rax + (b.right - _rax) * _rsx,
        bottom: _ray + (b.bottom - _ray) * _rsy,
      );
    }
    final b = StrokeSelection.pointBoundsOf(selectedStrokes);
    if (b == null) return null;
    return (
      left: b.left + _dx,
      top: b.top + _dy,
      right: b.right + _dx,
      bottom: b.bottom + _dy,
    );
  }

  /// Points of [s] as they look during a resize drag.
  List<StrokePoint> previewPoints(Stroke s) => _mode == _Mode.resize
      ? StrokeSelection.scaleAbout(s, _rax, _ray, _rsx, _rsy).points
      : s.points;

  /// Handle positions around the selection (document units).
  List<HandleSpot> get handleSpots {
    final f = selectionFrame;
    if (f == null) return const [];
    final l = f.left - framePad, r = f.right + framePad;
    final t = f.top - framePad, b = f.bottom + framePad;
    final okX = f.right - f.left >= 1;
    final okY = f.bottom - f.top >= 1;
    final wide = (r - l) * _scale >= 72;
    final tall = (b - t) * _scale >= 72;
    final out = <HandleSpot>[];
    for (final h in SelectionHandle.values) {
      if (!h.isCorner) {
        if (h.fy == 0 && !(okX && tall)) continue;
        if (h.fx == 0 && !(okY && wide)) continue;
      }
      out.add((
        handle: h,
        x: h.fx < 0 ? l : (h.fx > 0 ? r : (l + r) / 2),
        y: h.fy < 0 ? t : (h.fy > 0 ? b : (t + b) / 2),
      ));
    }
    return out;
  }

  /// True when (x, y) is on a handle or inside the selection frame.
  bool hitsSelectionChrome(double x, double y) {
    if (_selected.isEmpty) return false;
    return _handleAt(x, y) != null || _inFrame(x, y);
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
    _cancelRefine();
    if (!canUndo) return;
    _selected.clear();
    _history.undo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  void redo() {
    _cancelRefine();
    if (!canRedo) return;
    _selected.clear();
    _history.redo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  /// Replaces all strokes, for example after loading a page.
  void replaceStrokes(List<Stroke> strokes) {
    _cancelRefine();
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
  /// or selecting. Shows the clean shape once a held stroke snapped.
  List<StrokePoint> get livePoints {
    final snapped = _recognized;
    if (snapped != null) return UnmodifiableListView(snapped.points);
    return _mode == _Mode.shape
        ? UnmodifiableListView(_shape)
        : _recorder.points;
  }

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

  // ---- Hold to snap ----

  void _armHold(double x, double y) {
    _holdArmed = _settings.shapeRecognition && _snap == null;
    if (!_holdArmed) return;
    _holdX = x;
    _holdY = y;
    _holdCount = _recorder.points.length;
    _restartHoldTimer();
  }

  /// Restarts the timer only when the pointer really moved, so jitter of a
  /// resting hand or stylus does not prevent the snap.
  void _trackHold(double x, double y) {
    if (!_holdArmed) return;
    final dx = x - _holdX;
    final dy = y - _holdY;
    if (dx * dx + dy * dy <= holdTolerance * holdTolerance) return;
    _holdX = x;
    _holdY = y;
    _holdCount = _recorder.points.length;
    _restartHoldTimer();
  }

  void _restartHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(holdDuration, _onHold);
  }

  void _onHold() {
    _holdTimer = null;
    if (_mode != _Mode.draw || !isDrawing || _recognized != null) return;

    // Points recorded while resting are jitter, not part of the shape.
    final points = _recorder.points;
    final count = _holdCount < 1
        ? 1
        : (_holdCount > points.length ? points.length : _holdCount);
    final shape = ShapeRecognizer.recognize(points.sublist(0, count));
    if (shape == null) return; // Keep the original stroke.

    _recognized = shape;
    notifyListeners();
    _live.ping();
    onShapeRecognized?.call();
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdArmed = false;
    _recognized = null;
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
    _cancelRefine();
    _downX = x;
    _downY = y;
    _deselectedOnDown = false;

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
        if (_selected.isNotEmpty) {
          if (_tryBeginSelectionGesture(x, y)) {
            notifyListeners();
            _live.ping();
            return true;
          }
          _selected.clear();
          _deselectedOnDown = true;
        }
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
        _armHold(x, y);
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
      case _Mode.resize:
        _updateResize(x, y);
        _live.ping();
      case _Mode.draw:
        // A snapped shape stays as it is until the pointer is lifted.
        if (_recognized != null) return;
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
        _trackHold(x, y);
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

      case _Mode.resize:
        _updateResize(x, y);
        final sx = _rsx, sy = _rsy, ax = _rax, ay = _ray;
        final before = selectedStrokes.toList();
        _finish();
        if ((sx - 1).abs() > 0.001 || (sy - 1).abs() > 0.001) {
          _history.execute(
            ReplaceStrokesCommand(before, [
              for (final s in before)
                StrokeSelection.scaleAbout(s, ax, ay, sx, sy),
            ]),
            _strokes,
          );
          _revision++;
        }
        notifyListeners();
        _live.ping();

      case _Mode.lasso:
        _lasso.add((x: x, y: y));
        _selected.clear();
        if (_isNear(x, y, _downX, _downY)) {
          final hit = _strokeAt(x, y);
          if (hit != null) _selected.add(hit);
        } else {
          _selected.addAll(StrokeSelection.insideLasso(_strokes, _lasso));
        }
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
        final recognized = _recognized;
        if (recognized == null &&
            _isNear(x, y, _downX, _downY) &&
            timeMs - _originMs <= 400) {
          final hit = _strokeAt(x, y);
          if (hit != null || _deselectedOnDown) {
            _recorder.cancel();
            _selected.clear();
            if (hit != null) _selected.add(hit);
            _finish();
            notifyListeners();
            _live.ping();
            break;
          }
        }
        if (recognized == null) {
          final p = _snapPoint(x, y);
          _recorder.add(
            StrokePoint(
              x: p.x,
              y: p.y,
              pressure: pressure,
              timestampMs: timeMs - _originMs,
            ),
          );
        }
        var stroke = _recorder.end();
        if (recognized != null) {
          // Same id, tool, color and width: only the geometry is cleaned.
          stroke = stroke.copyWith(points: recognized.points);
        } else if (_snap != null && stroke.points.length > 2) {
          // Snapped to the ruler: keep only the two ends of the line.
          stroke = stroke.copyWith(
            points: [stroke.points.first, stroke.points.last],
          );
        }
        final refine =
            recognized == null &&
            _snap == null &&
            _settings.shapeRecognition &&
            SmartStroke.isCandidate(stroke.points);
        _history.execute(AddStrokeCommand(stroke), _strokes);
        _revision++;
        _finish();
        if (refine) _scheduleRefine(stroke.id);
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
      case _Mode.resize:
        break;
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
    _stopHold();
    _mode = _Mode.none;
    _activePointer = null;
    _snap = null;
    _handle = null;
    _resizeBox = null;
    _rsx = 1;
    _rsy = 1;
    _deselectedOnDown = false;
  }

  void _beginSelect(double x, double y) {
    if (!_tryBeginSelectionGesture(x, y)) {
      _selected.clear();
      _mode = _Mode.lasso;
      _lasso
        ..clear()
        ..add((x: x, y: y));
    }
    notifyListeners();
    _live.ping();
  }

  bool _inFrame(double x, double y) {
    final f = selectionFrame;
    if (f == null) return false;
    const slop = framePad + _grabSlop;
    return x >= f.left - slop &&
        x <= f.right + slop &&
        y >= f.top - slop &&
        y <= f.bottom + slop;
  }

  SelectionHandle? _handleAt(double x, double y) {
    final reach = handleHitPx / _scale;
    SelectionHandle? best;
    var bestDistance = double.infinity;
    for (final s in handleSpots) {
      final d = math.max((x - s.x).abs(), (y - s.y).abs());
      if (d <= reach && d < bestDistance) {
        best = s.handle;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Handle -> resize, inside the frame -> move. False when neither applies.
  bool _tryBeginSelectionGesture(double x, double y) {
    final handle = _handleAt(x, y);
    if (handle != null) {
      _beginResize(handle, x, y);
      return true;
    }
    if (_inFrame(x, y)) {
      _mode = _Mode.move;
      _moveFromX = x;
      _moveFromY = y;
      _dx = 0;
      _dy = 0;
      return true;
    }
    return false;
  }

  void _beginResize(SelectionHandle h, double x, double y) {
    final b = StrokeSelection.pointBoundsOf(selectedStrokes)!;
    _mode = _Mode.resize;
    _handle = h;
    _resizeBox = b;
    _pressX = x;
    _pressY = y;
    _rsx = 1;
    _rsy = 1;
    _rax = h.fx > 0 ? b.left : (h.fx < 0 ? b.right : (b.left + b.right) / 2);
    _ray = h.fy > 0 ? b.top : (h.fy < 0 ? b.bottom : (b.top + b.bottom) / 2);
  }

  void _updateResize(double x, double y) {
    final box = _resizeBox;
    final h = _handle;
    if (box == null || h == null) return;
    final w = box.right - box.left;
    final ht = box.bottom - box.top;
    final okX = w >= 1;
    final okY = ht >= 1;
    final lowX = okX ? math.min(1.0, minShapeSide / w) : 0.0;
    final lowY = okY ? math.min(1.0, minShapeSide / ht) : 0.0;
    final dx = x - _pressX;
    final dy = y - _pressY;

    var sx = h.fx != 0 && okX ? math.max((w + h.fx * dx) / w, lowX) : 1.0;
    var sy = h.fy != 0 && okY ? math.max((ht + h.fy * dy) / ht, lowY) : 1.0;

    if (HardwareKeyboard.instance.isShiftPressed) {
      final u = math.max(
        (sx - 1).abs() >= (sy - 1).abs() ? sx : sy,
        math.max(lowX, lowY),
      );
      sx = okX ? u : 1.0;
      sy = okY ? u : 1.0;
    }
    _rsx = sx;
    _rsy = sy;
  }

  // ---- Tap selection ----

  bool _isNear(double x, double y, double fromX, double fromY) {
    final slop = tapSlopPx / _scale;
    final dx = x - fromX;
    final dy = y - fromY;
    return dx * dx + dy * dy <= slop * slop;
  }

  /// Id of the top-most stroke under (x, y), or null.
  String? _strokeAt(double x, double y) {
    final radius = 10 / _scale;
    for (var i = _strokes.length - 1; i >= 0; i--) {
      if (StrokeHitTest.hitsSegment(
        _strokes[i],
        ax: x,
        ay: y,
        bx: x,
        by: y,
        radius: radius,
      )) {
        return _strokes[i].id;
      }
    }
    return null;
  }

  // ---- Auto recognition after the stroke ----

  void _scheduleRefine(String id) {
    _refineTimer?.cancel();
    _refineTimer = Timer(refineDelay, () => _onRefine(id));
  }

  void _cancelRefine() {
    _refineTimer?.cancel();
    _refineTimer = null;
  }

  void _onRefine(String id) {
    _refineTimer = null;
    if (isDrawing) return;
    final i = _strokes.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final before = _strokes[i];
    final points = SmartStroke.refine(before.points);
    if (points == null) return;
    _history.execute(
      ReplaceStrokesCommand([before], [before.copyWith(points: points)]),
      _strokes,
    );
    _revision++;
    notifyListeners();
    _live.ping();
    onShapeRecognized?.call();
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
    _holdTimer?.cancel();
    _cancelRefine();
    _settings.removeListener(_onSettingsChanged);
    if (_ownsSettings) _settings.dispose();
    _live.dispose();
    super.dispose();
  }
}
