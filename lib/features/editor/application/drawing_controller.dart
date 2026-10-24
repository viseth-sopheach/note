import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:uuid/uuid.dart';

import '../domain/command_history.dart';
import '../domain/drawing_command.dart';
import '../domain/selection_handle.dart';
import '../domain/shape_center.dart';
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

enum _Mode { none, draw, erase, lasso, move, shape, resize, endpoint }

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
    this.holdDuration = const Duration(milliseconds: 700),
    this.refineDelay = const Duration(milliseconds: 700),
    this.autoRefine = false,
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

  /// Extra area around the selection that still grabs it, in screen px.
  static const double _grabSlop = 8;

  /// A stroke that starts this close to a ruler edge snaps onto it.
  static const double snapDistance = 24;

  /// Pointer jitter below this distance (document units) still counts as
  /// holding still.
  static const double holdTolerance = 3;

  static const double framePad = 8;
  static const double handleHitPx = 14; // half size: 28 px target
  static const double handleDiameterPx = 10;
  static const double minFramePx = 24;
  static const double tapSlopPx = 6;
  static const double minShapeSide = 12;

  /// How long the pointer must rest at the end of a stroke to snap it.
  final Duration holdDuration;

  /// Pause after a stroke ends before it is recognized or smoothed.
  final Duration refineDelay;

  /// Smooth or snap strokes automatically after lifting. Off: shapes only
  /// snap when the pointer is held.
  final bool autoRefine;

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
  bool _lockAspect = false;

  // Endpoint drag state.
  bool _epMovesEnd = true;
  double _epAx = 0, _epAy = 0, _epMx = 0, _epMy = 0;
  double _epA = 1, _epB = 0;

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

  bool get isResizingSelection =>
      _mode == _Mode.resize || _mode == _Mode.endpoint;

  bool get isTransformingSelection =>
      _mode == _Mode.move || _mode == _Mode.resize || _mode == _Mode.endpoint;

  SelectionHandle? get activeHandle => _handle;

  double get _scale => (viewScale?.call() ?? 1.0).clamp(0.05, 20.0).toDouble();

  /// Frame padding in document units (constant on screen).
  double get framePadDoc => framePad / _scale;

  void refreshView() => _live.ping();

  // ---- Frame, preview, handles ----

  Bounds? get _rawFrame {
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

  /// Live selection bounds, never thinner than [minFramePx] on screen.
  Bounds? get selectionFrame {
    final f = _rawFrame;
    if (f == null) return null;
    final min = minFramePx / _scale;
    var l = f.left, r = f.right, t = f.top, b = f.bottom;
    if (r - l < min) {
      final c = (l + r) / 2;
      l = c - min / 2;
      r = c + min / 2;
    }
    if (b - t < min) {
      final c = (t + b) / 2;
      t = c - min / 2;
      b = c + min / 2;
    }
    return (left: l, top: t, right: r, bottom: b);
  }

  Stroke? get _linearStroke {
    if (_selected.length != 1) return null;
    for (final s in _strokes) {
      if (_selected.contains(s.id)) {
        return StrokeSelection.linearEnds(s) == null ? null : s;
      }
    }
    return null;
  }

  /// Live endpoints when the selection is one line or open freehand stroke.
  ({Vertex start, Vertex end})? get linearEnds {
    final s = _linearStroke;
    if (s == null) return null;
    final e = StrokeSelection.linearEnds(s)!;
    switch (_mode) {
      case _Mode.move:
        return (
          start: (x: e.start.x + _dx, y: e.start.y + _dy),
          end: (x: e.end.x + _dx, y: e.end.y + _dy),
        );
      case _Mode.endpoint:
        final m = _epMap(_epMx, _epMy);
        return _epMovesEnd ? (start: e.start, end: m) : (start: m, end: e.end);
      default:
        return e;
    }
  }

  Vertex _epMap(double x, double y) {
    final dx = x - _epAx, dy = y - _epAy;
    return (x: _epAx + _epA * dx - _epB * dy, y: _epAy + _epB * dx + _epA * dy);
  }

  List<StrokePoint> previewPoints(Stroke s) => switch (_mode) {
    _Mode.resize => StrokeSelection.scaleAbout(
      s,
      _rax,
      _ray,
      _rsx,
      _rsy,
    ).points,
    _Mode.endpoint => StrokeSelection.similarityAbout(
      s,
      _epAx,
      _epAy,
      _epA,
      _epB,
    ).points,
    _ => s.points,
  };

  /// Two endpoint handles for lines and freehand strokes, up to eight box
  /// handles for everything else (document units).
  List<HandleSpot> get handleSpots {
    final ends = linearEnds;
    if (ends != null) {
      return [
        (handle: SelectionHandle.start, x: ends.start.x, y: ends.start.y),
        (handle: SelectionHandle.end, x: ends.end.x, y: ends.end.y),
      ];
    }
    final raw = _rawFrame;
    final f = selectionFrame;
    if (raw == null || f == null) return const [];
    final pad = framePadDoc;
    final l = f.left - pad, r = f.right + pad;
    final t = f.top - pad, b = f.bottom + pad;
    final okX = raw.right - raw.left >= 1;
    final okY = raw.bottom - raw.top >= 1;
    final wide = (r - l) * _scale >= 72;
    final tall = (b - t) * _scale >= 72;
    final out = <HandleSpot>[];
    for (final h in SelectionHandle.values) {
      if (h.isEndpoint) continue;
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
      case _Mode.endpoint:
        _updateEndpoint(x, y);
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

      case _Mode.endpoint:
        _updateEndpoint(x, y);
        final ea = _epA, eb = _epB, eax = _epAx, eay = _epAy;
        final eBefore = selectedStrokes.toList();
        _finish();
        if ((ea - 1).abs() > 0.001 || eb.abs() > 0.001) {
          _history.execute(
            ReplaceStrokesCommand(eBefore, [
              for (final s in eBefore)
                StrokeSelection.similarityAbout(s, eax, eay, ea, eb),
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
        _expandSelection();
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
          final dot = _settings.tool == StrokeTool.ellipse
              ? ShapeCenter.dotFor(stroke)
              : null;
          _history.execute(
            dot == null
                ? AddStrokeCommand(stroke)
                : CompositeCommand([
                    AddStrokeCommand(stroke),
                    AddStrokeCommand(dot),
                  ]),
            _strokes,
          );
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
            _expandSelection();
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
        Stroke? dot;
        if (recognized != null) {
          // Same id, tool, color and width: only the geometry is cleaned.
          stroke = stroke.copyWith(points: recognized.points);
          if (_isEllipseKind(recognized.kind)) dot = ShapeCenter.dotFor(stroke);
        } else if (_snap != null && stroke.points.length > 2) {
          // Snapped to the ruler: keep only the two ends of the line.
          stroke = stroke.copyWith(
            points: [stroke.points.first, stroke.points.last],
          );
        }
        final refine =
            autoRefine &&
            recognized == null &&
            _snap == null &&
            _settings.shapeRecognition &&
            SmartStroke.isCandidate(stroke.points);
        _history.execute(
          dot == null
              ? AddStrokeCommand(stroke)
              : CompositeCommand([
                  AddStrokeCommand(stroke),
                  AddStrokeCommand(dot),
                ]),
          _strokes,
        );
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
      case _Mode.endpoint:
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
    _epA = 1;
    _epB = 0;
    _lockAspect = false;
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
    final slop = (framePad + _grabSlop) / _scale;
    final line = _linearStroke;
    if (line != null) {
      return StrokeHitTest.hitsSegment(
        line,
        ax: x,
        ay: y,
        bx: x,
        by: y,
        radius: slop,
      );
    }
    final f = selectionFrame;
    if (f == null) return false;
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

  /// Handle -> resize or endpoint drag, inside the frame -> move. False
  /// when neither applies.
  bool _tryBeginSelectionGesture(double x, double y) {
    final handle = _handleAt(x, y);
    if (handle != null) {
      if (handle.isEndpoint) {
        _beginEndpoint(handle, x, y);
      } else {
        _beginResize(handle, x, y);
      }
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

  void _expandSelection() {
    if (_selected.isEmpty) return;
    final all = ShapeCenter.withCompanions(_strokes, _selected);
    _selected
      ..clear()
      ..addAll(all);
  }

  void _beginEndpoint(SelectionHandle h, double x, double y) {
    final e = StrokeSelection.linearEnds(_linearStroke!)!;
    _epMovesEnd = h == SelectionHandle.end;
    final moving = _epMovesEnd ? e.end : e.start;
    final anchor = _epMovesEnd ? e.start : e.end;
    _mode = _Mode.endpoint;
    _handle = h;
    _epAx = anchor.x;
    _epAy = anchor.y;
    _epMx = moving.x;
    _epMy = moving.y;
    _epA = 1;
    _epB = 0;
    _pressX = x;
    _pressY = y;
  }

  /// Rotates and scales the stroke about the fixed end so the dragged end
  /// follows the pointer. A line just moves its end. Snaps to 45 degrees
  /// when close, and to 15 degrees while Shift is held.
  void _updateEndpoint(double x, double y) {
    final ux = _epMx - _epAx, uy = _epMy - _epAy;
    final ul2 = ux * ux + uy * uy;
    if (ul2 < 1e-9) return;
    var vx = _epMx + (x - _pressX) - _epAx;
    var vy = _epMy + (y - _pressY) - _epAy;
    var len = math.sqrt(vx * vx + vy * vy);
    if (len < 1e-6) {
      vx = ux;
      vy = uy;
      len = math.sqrt(ul2);
    }
    var ang = math.atan2(vy, vx);
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final step = shift ? math.pi / 12 : math.pi / 4;
    final snapped = (ang / step).roundToDouble() * step;
    if (shift || (ang - snapped).abs() <= 0.04) ang = snapped;
    len = math.max(len, 8 / _scale);
    vx = len * math.cos(ang);
    vy = len * math.sin(ang);
    _epA = (vx * ux + vy * uy) / ul2;
    _epB = (vy * ux - vx * uy) / ul2;
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

    // Squares and circles keep their aspect ratio by default when dragged
    // by a corner; Shift temporarily unlocks them.
    final solid = selectedStrokes.where((s) => !ShapeCenter.isDot(s)).toList();
    final bw = b.right - b.left, bh = b.bottom - b.top;
    _lockAspect =
        solid.length == 1 &&
        StrokeSelection.isClosed(solid.first) &&
        bw >= 1 &&
        bh >= 1 &&
        (bw - bh).abs() <= 0.03 * math.max(bw, bh);
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

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final uniform = h.isCorner ? shift != _lockAspect : shift;
    if (uniform) {
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
    final refined = SmartStroke.refineDetailed(before.points);
    if (refined == null) return;
    final after = before.copyWith(points: refined.points);
    final dot = _isEllipseKind(refined.kind) ? ShapeCenter.dotFor(after) : null;
    final replace = ReplaceStrokesCommand([before], [after]);
    _history.execute(
      dot == null
          ? replace
          : CompositeCommand([replace, AddStrokeCommand(dot)]),
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

  static bool _isEllipseKind(ShapeKind? k) =>
      k == ShapeKind.circle || k == ShapeKind.ellipse;

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
