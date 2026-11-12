import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:uuid/uuid.dart';

import '../domain/arrow_shape.dart';
import '../domain/command_history.dart';
import '../domain/drawing_command.dart';
import '../domain/pen_filter.dart';
import '../domain/selection_handle.dart';
import '../domain/shape_center.dart';
import '../domain/shape_choice.dart';
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

enum _Mode { none, draw, erase, lasso, move, shape, resize, endpoint, rotate }

/// Holds the strokes of one page, the stroke being drawn and the current
/// selection. Tool, color and width come from [settings], which can be
/// shared by the controllers of several pages.
///
/// Only strokes with a non-null [Stroke.shape] (line, rectangle, ellipse,
/// triangle, arrow) can be hovered, selected, copied or transformed.
/// Freehand strokes never enter the selection.
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
    double minDistance = 1.5,
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

  /// Max points used to glide the filtered pen tip onto the release point.
  static const int _glideSteps = 16;

  static const double framePad = 8;
  static const double handleHitPx = 14; // half size: 28 px target
  static const double handleDiameterPx = 10;
  static const double minFramePx = 24;
  static const double tapSlopPx = 6;
  static const double minShapeSide = 12;

  /// Distance of the rotate handle from the selection, in screen px.
  static const double rotateOffsetPx = 30;
  static const double _rotateSnap = math.pi / 12;

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
  final PenFilter _pen = PenFilter();

  late StrokeTool _seenTool;

  _Mode _mode = _Mode.none;
  List<Stroke>? _eraseBefore;
  bool _eraseChanged = false;
  double _lastX = 0;
  double _lastY = 0;

  final List<Vertex> _lasso = [];
  final Set<String> _selected = {};
  String? _hoverId;
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

  // Recent finished pen strokes, for shaft + arrowhead merging.
  final Stopwatch _clock = Stopwatch()..start();
  final List<({String id, int at})> _recent = [];
  static const int _mergeWindowMs = 2500;
  static const bool _mergeArrows = false;

  Timer? _refineTimer;
  SelectionHandle? _handle;
  Bounds? _resizeBox;
  double _pressX = 0, _pressY = 0, _downX = 0, _downY = 0;
  double _rsx = 1, _rsy = 1, _rax = 0, _ray = 0;
  bool _deselectedOnDown = false;
  bool _lockAspect = false;

  // Line endpoint drag state.
  bool _epMovesEnd = true;
  double _epAx = 0, _epAy = 0; // fixed end
  double _epMx = 0, _epMy = 0; // dragged end when the drag began
  double _epTx = 0, _epTy = 0; // dragged end now

  // Rotation state.
  double _rcx = 0, _rcy = 0, _rotStart = 0, _rot = 0;

  int? _activePointer;
  int _originMs = 0;
  int _revision = 0;
  int _inkEpoch = 0;

  ToolSettings get settings => _settings;
  StrokeTool get tool => _settings.tool;
  int get colorValue => _settings.colorValue;
  double get width => _settings.width;

  /// Id of the stroke currently being drawn, or null when idle.
  /// Stable for the whole life of the live stroke, used as the live ink
  /// cache key. Cleared by [StrokeRecorder.cancel] / [StrokeRecorder.end].
  String? get liveStrokeId => _recorder.id;

  // ---- Shape rules ----

  /// Every stored stroke can be hit-tested. Only shapes (or their center
  /// dots) are selectable via tap or lasso, gated by [_expandSelection] and
  /// the `shape == null` checks at the call sites.
  bool _selectable(Stroke s) => !ShapeCenter.isDot(s);

  static ShapeKind? _stored(ShapeKind? k) => switch (k) {
    ShapeKind.line => ShapeKind.line,
    ShapeKind.rectangle || ShapeKind.square => ShapeKind.rectangle,
    ShapeKind.circle || ShapeKind.ellipse => ShapeKind.ellipse,
    ShapeKind.triangle => ShapeKind.triangle,
    ShapeKind.arrow => ShapeKind.arrow,
    _ => null, // star, polygon
  };

  static ShapeKind? _fromTool(StrokeTool t) => switch (t) {
    StrokeTool.line => ShapeKind.line,
    StrokeTool.rectangle => ShapeKind.rectangle,
    StrokeTool.ellipse => ShapeKind.ellipse,
    StrokeTool.triangle => ShapeKind.triangle,
    StrokeTool.arrow => ShapeKind.arrow,
    _ => null,
  };

  void _onSettingsChanged() {
    if (_settings.tool != _seenTool) {
      _seenTool = _settings.tool;
      _selected.clear();
      _hoverId = null;
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

  /// Changes on every change to the strokes, including loading a page.
  /// Unlike [revision], it is safe to use as a render-cache key.
  int get inkEpoch => _inkEpoch + _revision;

  // ---- Hover ----

  /// Id of the selectable shape under the mouse, or null.
  String? get hoverId => _hoverId;

  void hoverAt(double x, double y) {
    if (isDrawing || _settings.tool == StrokeTool.eraser) {
      clearHover();
      return;
    }
    final id = _strokeAt(x, y);
    if (id == _hoverId) return;
    _hoverId = id;
    _live.ping();
  }

  void clearHover() {
    if (_hoverId == null) return;
    _hoverId = null;
    _live.ping();
  }

  /// Selects the top-most stroke under (x, y). With [shapesOnly], only
  /// non-freehand strokes are eligible. Returns true when a stroke was
  /// selected. Does nothing while a stroke is being drawn.
  bool selectAt(
    double x,
    double y, {
    bool shapesOnly = false,
    bool duringStroke = false,
  }) {
    if (isDrawing && !duringStroke) return false;
    final radius = (shapesOnly ? 14 : 10) / _scale;
    for (var i = _strokes.length - 1; i >= 0; i--) {
      final s = _strokes[i];
      if (!_selectable(s)) continue;
      if (shapesOnly && s.shape == null) continue;
      if (StrokeHitTest.hitsSegment(
        s,
        ax: x,
        ay: y,
        bx: x,
        by: y,
        radius: radius,
      )) {
        _selected
          ..clear()
          ..add(s.id);
        _expandSelection();
        notifyListeners();
        _live.ping();
        return true;
      }
    }
    return false;
  }

  /// Pastes the clipboard so its bounding-box center lands on (x, y).
  /// Does nothing while drawing, when the clipboard is empty, or when the
  /// clipboard has no points.
  void pasteAt(double x, double y) {
    if (isDrawing || _clipboard.isEmpty) return;
    final b = StrokeSelection.pointBoundsOf(_clipboard);
    if (b == null) return;
    _insertCopies(
      _clipboard,
      x - (b.left + b.right) / 2,
      y - (b.top + b.bottom) / 2,
    );
  }

  // ---- Selection state ----

  Set<String> get selectedIds => UnmodifiableSetView(_selected);

  bool get hasSelection => _selected.isNotEmpty;

  bool get isMovingSelection => _mode == _Mode.move;

  bool get isRotatingSelection => _mode == _Mode.rotate;

  /// Lasso path being drawn; empty when idle.
  List<Vertex> get lasso => UnmodifiableListView(_lasso);

  double get selectionDx => _dx;

  double get selectionDy => _dy;

  Iterable<Stroke> get selectedStrokes =>
      _strokes.where((s) => _selected.contains(s.id));

  bool get isResizingSelection =>
      _mode == _Mode.resize || _mode == _Mode.endpoint;

  bool get isTransformingSelection =>
      _mode == _Mode.move ||
      _mode == _Mode.resize ||
      _mode == _Mode.endpoint ||
      _mode == _Mode.rotate;

  SelectionHandle? get activeHandle => _handle;

  double get _scale => (viewScale?.call() ?? 1.0).clamp(0.05, 20.0).toDouble();

  /// Frame padding in document units (constant on screen).
  double get framePadDoc => framePad / _scale;

  void refreshView() => _live.ping();

  // ---- Frame, preview, handles ----

  Bounds? get _rawFrame {
    if (_selected.isEmpty) return null;
    if (_mode == _Mode.rotate) {
      final c = math.cos(_rot), s = math.sin(_rot);
      return StrokeSelection.pointBoundsOf([
        for (final st in selectedStrokes)
          StrokeSelection.similarityAbout(st, _rcx, _rcy, c, s),
      ]);
    }
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

  /// The selected stroke when exactly one non-dot Line/Arrow shape is
  /// selected.
  Stroke? get _linearStroke {
    if (_selected.length != 1) return null;
    for (final s in _strokes) {
      if (_selected.contains(s.id)) {
        if (ShapeCenter.isDot(s)) return null;
        return StrokeSelection.linearEnds(s) == null ? null : s;
      }
    }
    return null;
  }

  /// Live endpoints when the selection is one Line or Arrow shape.
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
        final Vertex t = (x: _epTx, y: _epTy);
        return _epMovesEnd ? (start: e.start, end: t) : (start: t, end: e.end);
      case _Mode.rotate:
        final c = math.cos(_rot), s = math.sin(_rot);
        Vertex rot(Vertex v) => (
          x: _rcx + c * (v.x - _rcx) - s * (v.y - _rcy),
          y: _rcy + s * (v.x - _rcx) + c * (v.y - _rcy),
        );
        return (start: rot(e.start), end: rot(e.end));
      default:
        return e;
    }
  }

  /// Endpoint drag for a line or arrow. Lines move just the dragged end;
  /// arrows are rebuilt in place so barbs stay proportional.
  List<StrokePoint> _linePoints(Stroke s, bool movesEnd, double x, double y) {
    if (s.shape == ShapeKind.arrow) {
      final e = StrokeSelection.linearEnds(s)!;
      final Vertex moved = (x: x, y: y);
      return ArrowShape.rebuild(
        s.points,
        tail: movesEnd ? e.start : moved,
        tip: movesEnd ? moved : e.end,
      );
    }
    final a = s.points.first, b = s.points.last;
    return movesEnd
        ? [
            a,
            StrokePoint(
              x: x,
              y: y,
              pressure: b.pressure,
              timestampMs: b.timestampMs,
            ),
          ]
        : [
            StrokePoint(
              x: x,
              y: y,
              pressure: a.pressure,
              timestampMs: a.timestampMs,
            ),
            b,
          ];
  }

  List<StrokePoint> previewPoints(Stroke s) => switch (_mode) {
    _Mode.resize => StrokeSelection.scaleAbout(
      s,
      _rax,
      _ray,
      _rsx,
      _rsy,
    ).points,
    _Mode.endpoint => _linePoints(s, _epMovesEnd, _epTx, _epTy),
    _Mode.rotate => StrokeSelection.similarityAbout(
      s,
      _rcx,
      _rcy,
      math.cos(_rot),
      math.sin(_rot),
    ).points,
    _ => s.points,
  };

  /// Rotate handle sits on the inside of the segment's normal, at a fixed
  /// screen offset from the midpoint.
  ({double x, double y})? _lineRotateSpot(({Vertex start, Vertex end}) e) {
    final dx = e.end.x - e.start.x, dy = e.end.y - e.start.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return null;
    var nx = -dy / len, ny = dx / len;
    if (ny > 0) {
      nx = -nx;
      ny = -ny;
    }
    final off = rotateOffsetPx / _scale;
    return (
      x: (e.start.x + e.end.x) / 2 + nx * off,
      y: (e.start.y + e.end.y) / 2 + ny * off,
    );
  }

  /// Endpoint handles plus rotate for lines and arrows; up to eight box
  /// handles plus rotate for other shapes (document units).
  List<HandleSpot> get handleSpots {
    final ends = linearEnds;
    if (ends != null) {
      final rs = _lineRotateSpot(ends);
      return [
        (handle: SelectionHandle.start, x: ends.start.x, y: ends.start.y),
        (handle: SelectionHandle.end, x: ends.end.x, y: ends.end.y),
        if (rs != null) (handle: SelectionHandle.rotate, x: rs.x, y: rs.y),
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
      if (h.isEndpoint || h.isRotate) continue;
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
    out.add((
      handle: SelectionHandle.rotate,
      x: (l + r) / 2,
      y: t - rotateOffsetPx / _scale,
    ));
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

  // ---- Convert selected shape ----

  Stroke? get _convertible {
    Stroke? found;
    for (final s in _strokes) {
      if (!_selected.contains(s.id) || ShapeCenter.isDot(s)) continue;
      if (found != null) return null;
      found = s;
    }
    final k = found?.shape;
    return k == ShapeKind.rectangle ||
            k == ShapeKind.ellipse ||
            k == ShapeKind.triangle
        ? found
        : null;
  }

  /// True when exactly one closed shape is selected.
  bool get canConvertSelection => !isDrawing && _convertible != null;

  void convertSelectionTo(ShapeChoice choice) {
    if (isDrawing) return;
    final old = _convertible;
    if (old == null) return;
    final b = StrokeSelection.pointBoundsOf([old]);
    if (b == null) return;

    final cx = (b.left + b.right) / 2;
    final cy = (b.top + b.bottom) / 2;
    var w = b.right - b.left;
    var h = b.bottom - b.top;
    if (choice == ShapeChoice.circle || choice == ShapeChoice.square) {
      w = h = math.max(w, h);
    }
    final tool = switch (choice) {
      ShapeChoice.circle || ShapeChoice.ellipse => StrokeTool.ellipse,
      ShapeChoice.square || ShapeChoice.rectangle => StrokeTool.rectangle,
      ShapeChoice.triangle => StrokeTool.triangle,
    };

    final next = old.copyWith(
      points: ShapeGeometry.build(
        tool,
        x0: cx - w / 2,
        y0: cy - h / 2,
        x1: cx + w / 2,
        y1: cy + h / 2,
      ),
      shape: _fromTool(tool),
    );

    final commands = <DrawingCommand>[
      ReplaceStrokesCommand([old], [next]),
    ];
    final dotId = ShapeCenter.dotId(old.id);
    final dotIndex = _strokes.indexWhere((s) => s.id == dotId);
    if (dotIndex >= 0) {
      commands.add(RemoveStrokesCommand()..take(_strokes, dotIndex));
    }
    final dot = tool == StrokeTool.ellipse ? ShapeCenter.dotFor(next) : null;
    if (dot != null) commands.add(AddStrokeCommand(dot));

    _history.execute(CompositeCommand(commands), _strokes);
    _revision++;
    _selected
      ..clear()
      ..add(next.id);
    _expandSelection();
    notifyListeners();
    _live.ping();
  }

  // ---- Highlight (fill) selected shapes ----

  /// Selected shapes only. Freehand strokes and center dots are never touched.
  List<Stroke> get _shapeSelection => [
    for (final s in _strokes)
      if (_selected.contains(s.id) && !ShapeCenter.isDot(s) && s.shape != null)
        s,
  ];

  static bool _fillable(Stroke s) =>
      s.shape == ShapeKind.rectangle ||
      s.shape == ShapeKind.ellipse ||
      s.shape == ShapeKind.triangle;

  List<Stroke> get _fillableSelection => [
    for (final s in _shapeSelection)
      if (_fillable(s)) s,
  ];

  /// True when the selection has a closed shape that can be filled.
  bool get canHighlightSelection => !isDrawing && _fillableSelection.isNotEmpty;

  /// True when every fillable selected shape is already filled.
  bool get selectionHighlighted {
    final shapes = _fillableSelection;
    return shapes.isNotEmpty && shapes.every((s) => s.filled);
  }

  /// Shared fill color of the selected closed shapes, or null when they
  /// differ or none is filled.
  int? get selectionFillColorValue {
    final shapes = _fillableSelection;
    if (shapes.isEmpty) return null;
    final first = shapes.first.fillColorValue;
    return shapes.every((s) => s.fillColorValue == first) ? first : null;
  }

  /// Fills the interior of the selected closed shapes with [colorValue].
  void highlightSelection(int colorValue) => _setFill(colorValue);

  /// Removes the fill from the selected closed shapes.
  void removeSelectionHighlight() => _setFill(null);

  /// One undo step. Border, width and border color are never changed.
  void _setFill(int? value) {
    if (isDrawing) return;
    final shapes = [
      for (final s in _fillableSelection)
        if (s.fillColorValue != value) s,
    ];
    if (shapes.isEmpty) return;

    _history.execute(
      ReplaceStrokesCommand(shapes, [
        for (final s in shapes) s.copyWith(fillColorValue: value),
      ]),
      _strokes,
    );
    _revision++;
    notifyListeners();
    _live.ping();
  }

  // ---- Change color of selected shapes ----

  bool get canRecolorSelection => !isDrawing && _shapeSelection.isNotEmpty;

  /// Shared color of the selected shapes, or null when they differ.
  int? get selectionColorValue {
    final shapes = _shapeSelection;
    if (shapes.isEmpty) return null;
    final first = shapes.first.colorValue;
    return shapes.every((s) => s.colorValue == first) ? first : null;
  }

  /// Recolors the selected shapes (and the center dot of a selected ellipse).
  /// Other strokes are never touched. One undo step.
  void changeSelectionColor(int colorValue) {
    if (isDrawing) return;
    final targets = [
      for (final s in _strokes)
        if (_selected.contains(s.id) &&
            (s.shape != null || ShapeCenter.isDot(s)) &&
            s.colorValue != colorValue)
          s,
    ];
    if (targets.isEmpty) return;

    _history.execute(
      ReplaceStrokesCommand(targets, [
        for (final s in targets) s.copyWith(colorValue: colorValue),
      ]),
      _strokes,
    );
    _revision++;
    notifyListeners();
    _live.ping();
  }

  // ---- Copy / duplicate / paste ----

  static const double duplicateOffset = 24;
  static List<Stroke> _clipboard = const [];
  static int _pasteStep = 0;

  static bool get hasClipboard => _clipboard.isNotEmpty;

  /// Selectable shapes plus the center dots that belong to them.
  List<Stroke> _copyable() => [
    for (final s in selectedStrokes)
      if (_selectable(s) || ShapeCenter.isDot(s)) s,
  ];

  void copySelection() {
    if (isDrawing || _selected.isEmpty) return;
    _clipboard = _copyable();
    _pasteStep = 0;
    notifyListeners();
  }

  void pasteClipboard() {
    if (isDrawing || _clipboard.isEmpty) return;
    final d = duplicateOffset * (++_pasteStep);
    _insertCopies(_clipboard, d, d);
  }

  void duplicateSelection() {
    if (isDrawing || _selected.isEmpty) return;
    _insertCopies(_copyable(), duplicateOffset, duplicateOffset);
  }

  void _insertCopies(List<Stroke> source, double dx, double dy) {
    if (source.isEmpty) return;
    _cancelRefine();

    final idMap = <String, String>{};
    for (final s in source) {
      if (!ShapeCenter.isDot(s)) idMap[s.id] = _newId();
    }

    final copies = <Stroke>[];
    for (final s in source) {
      final String id;
      if (ShapeCenter.isDot(s)) {
        id = ShapeCenter.dotId(idMap[ShapeCenter.ownerOf(s.id)] ?? _newId());
      } else {
        id = idMap[s.id]!;
      }
      final moved = StrokeSelection.translate(s, dx, dy);
      copies.add(
        Stroke(
          id: id,
          tool: moved.tool,
          colorValue: moved.colorValue,
          width: moved.width,
          points: moved.points,
          shape: moved.shape,
          fillColorValue: moved.fillColorValue,
        ),
      );
    }

    _history.execute(
      CompositeCommand([for (final c in copies) AddStrokeCommand(c)]),
      _strokes,
    );
    _revision++;
    _selected
      ..clear()
      ..addAll(copies.map((c) => c.id));
    notifyListeners();
    _live.ping();
  }

  // ---- History ----

  void undo() {
    _cancelRefine();
    if (!canUndo) return;
    _selected.clear();
    _hoverId = null;
    _history.undo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  void redo() {
    _cancelRefine();
    if (!canRedo) return;
    _selected.clear();
    _hoverId = null;
    _history.redo(_strokes);
    _revision++;
    notifyListeners();
    _live.ping();
  }

  /// Replaces all strokes, for example after loading a page.
  void replaceStrokes(List<Stroke> strokes) {
    _cancelRefine();
    _inkEpoch++;
    if (isDrawing) return;
    _strokes
      ..clear()
      ..addAll(strokes);
    _selected.clear();
    _hoverId = null;
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
  /// resting hand or stylus does not prevent the snap. Uses raw coordinates.
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
    final shape = ShapeRecognizer.recognizeConfident(points.sublist(0, count));
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

  /// The pen filter lags the pointer. On lift, let it converge onto the
  /// release point so the stroke ends with a smooth tail, not a straight jump.
  void _glideTo(double x, double y, int t, double pressure) {
    for (var i = 0; i < _glideSteps; i++) {
      final last = _recorder.points.last;
      if ((last.x - x).abs() + (last.y - y).abs() < 0.5) break;
      final ts = t + (i + 1) * 8;
      final s = _pen.apply(x, y, ts);
      _recorder.add(
        StrokePoint(x: s.x, y: s.y, pressure: pressure, timestampMs: ts),
        force: true,
      );
    }
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
    _hoverId = null;
    _downX = x;
    _downY = y;
    _deselectedOnDown = false;

    switch (_settings.tool) {
      case StrokeTool.eraser:
        _mode = _Mode.erase;
        _eraseBefore = List<Stroke>.of(_strokes);
        _eraseChanged = false;
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
        // A pen/highlighter down on a handle grabs the selection; on ink
        // or empty space it just clears the selection and starts drawing.
        if (_selected.isNotEmpty) {
          // Handles and the frame body both grab the selection, so a selected
          // shape can be moved, resized or rotated without switching tools.
          if (_tryBeginSelectionGesture(x, y)) {
            notifyListeners();
            _live.ping();
            return true;
          }
          _selected.clear();
        }
        _mode = _Mode.draw;
        _originMs = timeMs;
        _snap = _findSnap(x, y);
        final start = _snapPoint(x, y);
        _pen.begin(start.x, start.y, 0);
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
      case StrokeTool.arrow:
        return _grabSelection(x, y) || _beginShape(x, y, snapToRuler: true);

      case StrokeTool.rectangle:
      case StrokeTool.ellipse:
      case StrokeTool.triangle:
        return _grabSelection(x, y) || _beginShape(x, y, snapToRuler: false);
    }
  }

  /// Starts a move/resize when the pointer is on the current selection.
  /// Otherwise clears the selection and returns false.
  bool _grabSelection(double x, double y) {
    if (_selected.isEmpty) return false;
    if (_tryBeginSelectionGesture(x, y)) {
      notifyListeners();
      _live.ping();
      return true;
    }
    _selected.clear();
    return false;
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
      case _Mode.rotate:
        _updateRotate(x, y);
        _live.ping();
      case _Mode.draw:
        // A snapped shape stays as it is until the pointer is lifted.
        if (_recognized != null) return;
        final p = _snapPoint(x, y);
        final t = timeMs - _originMs;
        // Smooth freehand input; ruler-snapped points are already straight.
        final ({double x, double y}) s = _snap == null
            ? _pen.apply(p.x, p.y, t)
            : p;
        _recorder.add(
          StrokePoint(x: s.x, y: s.y, pressure: pressure, timestampMs: t),
        );
        _live.ping(); // always, so the tip follows even when no point is kept
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
        _eraseTo(x, y);
        final before = _eraseBefore;
        if (_eraseChanged && before != null) {
          _history.record(SnapshotCommand(before, List<Stroke>.of(_strokes)));
          _revision++;
        }
        _eraseBefore = null;
        _eraseChanged = false;
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

      case _Mode.rotate:
        _updateRotate(x, y);
        final angle = _rot, cx = _rcx, cy = _rcy;
        final rBefore = selectedStrokes.toList();
        _finish();
        if (angle.abs() > 0.002) {
          final c = math.cos(angle), s = math.sin(angle);
          _history.execute(
            ReplaceStrokesCommand(rBefore, [
              for (final st in rBefore)
                StrokeSelection.similarityAbout(st, cx, cy, c, s),
            ]),
            _strokes,
          );
          _revision++;
        }
        notifyListeners();
        _live.ping();

      case _Mode.endpoint:
        _updateEndpoint(x, y);
        final tx = _epTx, ty = _epTy;
        final movesEnd = _epMovesEnd;
        final moved = math.sqrt(
          math.pow(tx - _epMx, 2) + math.pow(ty - _epMy, 2),
        );
        final eBefore = selectedStrokes.toList();
        _finish();
        if (moved >= 0.5 && eBefore.length == 1) {
          final s = eBefore.first;
          _history.execute(
            ReplaceStrokesCommand(
              [s],
              [s.copyWith(points: _linePoints(s, movesEnd, tx, ty))],
            ),
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
          final candidates = [
            for (final s in _strokes)
              if (_selectable(s)) s,
          ];
          _selected.addAll(StrokeSelection.insideLasso(candidates, _lasso));
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
            shape: _fromTool(_settings.tool),
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
          _selected
            ..clear()
            ..add(stroke.id);
          _expandSelection();
        }
        _shape.clear();
        _finish();
        notifyListeners();
        _live.ping();

      case _Mode.draw:
        final recognized = _recognized;

        if (recognized == null) {
          final p = _snapPoint(x, y);
          final t = timeMs - _originMs;
          if (_snap == null) _glideTo(p.x, p.y, t, pressure);
          _recorder.add(
            StrokePoint(x: p.x, y: p.y, pressure: pressure, timestampMs: t),
            force: true,
          );
        }
        var stroke = _recorder.end();
        Stroke? dot;
        if (recognized != null) {
          // Same id, tool, color and width: only the geometry is cleaned.
          stroke = stroke.copyWith(
            points: recognized.points,
            shape: _stored(recognized.kind),
          );
          if (_isEllipseKind(recognized.kind)) dot = ShapeCenter.dotFor(stroke);
        } else if (_snap != null && stroke.points.length >= 2) {
          // Snapped to the ruler: a two-point Line shape.
          stroke = stroke.copyWith(
            points: [stroke.points.first, stroke.points.last],
            shape: ShapeKind.line,
          );
        }
        final merge = recognized == null && _snap == null
            ? _findArrowMerge(stroke)
            : null;
        final refine =
            autoRefine &&
            recognized == null &&
            _snap == null &&
            merge == null &&
            _settings.shapeRecognition &&
            SmartStroke.isCandidate(stroke.points);
        if (merge != null) {
          _applyArrowMerge(stroke, merge);
        } else {
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
          if (recognized != null && stroke.shape != null) {
            _selected
              ..clear()
              ..add(stroke.id);
            _expandSelection();
          }
          if (stroke.tool == StrokeTool.pen) _remember(stroke.id);
        }
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
        final before = _eraseBefore;
        if (before != null) {
          _strokes
            ..clear()
            ..addAll(before);
          _inkEpoch++;
        }
        _eraseBefore = null;
        _eraseChanged = false;
      case _Mode.lasso:
        _lasso.clear();
      case _Mode.move:
        _dx = 0;
        _dy = 0;
      case _Mode.resize:
      case _Mode.endpoint:
      case _Mode.rotate:
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
    _rot = 0;
    _deselectedOnDown = false;
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

  /// Handle -> resize / endpoint / rotate, inside the frame -> move. False
  /// when neither applies.
  bool _tryBeginSelectionGesture(double x, double y) {
    final handle = _handleAt(x, y);
    if (handle != null) {
      if (handle.isEndpoint) {
        _beginEndpoint(handle, x, y);
      } else if (handle.isRotate) {
        _beginRotate(x, y);
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
    _epTx = moving.x;
    _epTy = moving.y;
    _pressX = x;
    _pressY = y;
  }

  /// Moves only the dragged end of a line (and rebuilds arrows about the
  /// fixed end); snaps to 15 degrees only while Shift is held.
  void _updateEndpoint(double x, double y) {
    var tx = _epMx + (x - _pressX);
    var ty = _epMy + (y - _pressY);
    var dx = tx - _epAx, dy = ty - _epAy;
    var len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return;

    if (HardwareKeyboard.instance.isShiftPressed) {
      const step = math.pi / 12;
      final a = (math.atan2(dy, dx) / step).roundToDouble() * step;
      tx = _epAx + len * math.cos(a);
      ty = _epAy + len * math.sin(a);
      dx = tx - _epAx;
      dy = ty - _epAy;
      len = math.sqrt(dx * dx + dy * dy);
    }
    if (len < 8 / _scale) return; // never collapse the line
    _epTx = tx;
    _epTy = ty;
  }

  void _beginRotate(double x, double y) {
    final b = StrokeSelection.pointBoundsOf(selectedStrokes)!;
    _mode = _Mode.rotate;
    _handle = SelectionHandle.rotate;
    _rcx = (b.left + b.right) / 2;
    _rcy = (b.top + b.bottom) / 2;
    _rotStart = math.atan2(y - _rcy, x - _rcx);
    _rot = 0;
  }

  /// Snaps to 15 degrees near a step, or always while Shift is held.
  void _updateRotate(double x, double y) {
    if ((x - _rcx).abs() < 1e-6 && (y - _rcy).abs() < 1e-6) return;
    var d = math.atan2(y - _rcy, x - _rcx) - _rotStart;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    final snapped = (d / _rotateSnap).roundToDouble() * _rotateSnap;
    if (HardwareKeyboard.instance.isShiftPressed ||
        (d - snapped).abs() <= 0.05) {
      d = snapped;
    }
    _rot = d;
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

  /// Id of the top-most selectable shape under (x, y), or null. Freehand
  /// strokes and ellipse center dots are skipped.
  String? _strokeAt(double x, double y) {
    final radius = 10 / _scale;
    for (var i = _strokes.length - 1; i >= 0; i--) {
      final s = _strokes[i];
      if (!_selectable(s)) continue;
      if (s.shape == null) continue;
      if (StrokeHitTest.hitsSegment(
        s,
        ax: x,
        ay: y,
        bx: x,
        by: y,
        radius: radius,
      )) {
        return s.id;
      }
    }
    return null;
  }

  /// Finds earlier strokes that, together with [latest], form an arrow.
  ({List<Stroke> parts, RecognizedShape shape})? _findArrowMerge(
    Stroke latest,
  ) {
    if (!_mergeArrows ||
        !_settings.shapeRecognition ||
        latest.tool != StrokeTool.pen) {
      return null;
    }
    final now = _clock.elapsedMilliseconds;
    final prior = <Stroke>[];
    for (final r in _recent.reversed) {
      if (now - r.at > _mergeWindowMs) break;
      final i = _strokes.indexWhere((s) => s.id == r.id);
      if (i < 0) break;
      final s = _strokes[i];
      if (s.tool != latest.tool ||
          s.colorValue != latest.colorValue ||
          s.width != latest.width ||
          ShapeCenter.isDot(s)) {
        break;
      }
      prior.insert(0, s);
      if (prior.length == 2) break;
    }
    for (var n = prior.length; n >= 1; n--) {
      final parts = prior.sublist(prior.length - n);
      final shape = ShapeRecognizer.recognizeArrowStrokes([
        for (final s in parts) s.points,
        latest.points,
      ]);
      if (shape != null) return (parts: parts, shape: shape);
    }
    return null;
  }

  void _applyArrowMerge(
    Stroke latest,
    ({List<Stroke> parts, RecognizedShape shape}) merge,
  ) {
    final ids = {for (final s in merge.parts) s.id};
    final remove = RemoveStrokesCommand();
    for (var i = _strokes.length - 1; i >= 0; i--) {
      if (ids.contains(_strokes[i].id)) remove.take(_strokes, i);
    }
    final arrow = Stroke(
      id: _newId(),
      tool: latest.tool,
      colorValue: latest.colorValue,
      width: latest.width,
      points: merge.shape.points,
      shape: ShapeKind.arrow,
    );
    _strokes.add(arrow);
    _history.record(CompositeCommand([remove, AddStrokeCommand(arrow)]));
    _revision++;
    _recent.clear();
    _selected
      ..clear()
      ..add(arrow.id);
    onShapeRecognized?.call();
  }

  void _remember(String id) {
    _recent.add((id: id, at: _clock.elapsedMilliseconds));
    if (_recent.length > 3) _recent.removeAt(0);
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
    final after = before.copyWith(
      points: refined.points,
      shape: _stored(refined.kind),
    );
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

  /// Erases only the parts of strokes within reach of the path from the last
  /// point to (x, y). Touched strokes are trimmed or split; untouched parts
  /// stay. Returns true when anything changed.
  bool _eraseTo(double x, double y) {
    final ax = _lastX, ay = _lastY;
    _lastX = x;
    _lastY = y;

    final next = <Stroke>[];
    final modified = <String>{};
    var changed = false;

    for (final s in _strokes) {
      if (!StrokeHitTest.hitsSegment(
        s,
        ax: ax,
        ay: ay,
        bx: x,
        by: y,
        radius: eraserRadius,
      )) {
        next.add(s);
        continue;
      }

      // A single dot that is touched disappears.
      if (s.points.length < 2) {
        changed = true;
        modified.add(s.id);
        continue;
      }

      final scale = s.tool == StrokeTool.highlighter
          ? StrokeHitTest.highlighterWidthScale
          : 1;
      final reach = eraserRadius + s.width * scale / 2;

      final dense = _densify(s.points, 5);
      final runs = <List<StrokePoint>>[];
      var cur = <StrokePoint>[];
      for (final p in dense) {
        if (_distToSegment(p.x, p.y, ax, ay, x, y) <= reach) {
          if (cur.isNotEmpty) {
            runs.add(cur);
            cur = <StrokePoint>[];
          }
        } else {
          cur.add(p);
        }
      }
      if (cur.isNotEmpty) runs.add(cur);

      if (runs.length == 1 && runs.first.length == dense.length) {
        next.add(s); // nothing was actually inside the eraser
        continue;
      }

      changed = true;
      modified.add(s.id);
      var first = true;
      for (final run in runs) {
        if (run.length < 2) continue;
        next.add(
          Stroke(
            id: first ? s.id : _newId(),
            tool: s.tool,
            colorValue: s.colorValue,
            width: s.width,
            points: run,
          ),
        );
        first = false;
      }
    }

    if (!changed) return false;

    // The center dot of an edited ellipse no longer matches it.
    next.removeWhere(
      (s) =>
          ShapeCenter.isDot(s) && modified.contains(ShapeCenter.ownerOf(s.id)),
    );

    _strokes
      ..clear()
      ..addAll(next);
    _eraseChanged = true;
    _inkEpoch++;
    return true;
  }

  /// Adds points so no segment is longer than [step]; originals are kept.
  static List<StrokePoint> _densify(List<StrokePoint> pts, double step) {
    if (pts.length < 2) return pts;
    final out = <StrokePoint>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final dx = b.x - a.x, dy = b.y - a.y;
      final n = (math.sqrt(dx * dx + dy * dy) / step).ceil();
      for (var k = 1; k < n; k++) {
        final t = k / n;
        out.add(
          StrokePoint(
            x: a.x + dx * t,
            y: a.y + dy * t,
            pressure: a.pressure + (b.pressure - a.pressure) * t,
            timestampMs: (a.timestampMs + (b.timestampMs - a.timestampMs) * t)
                .round(),
          ),
        );
      }
      out.add(b);
    }
    return out;
  }

  static double _distToSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final dx = bx - ax, dy = by - ay;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }
    final t = (((px - ax) * dx + (py - ay) * dy) / l2).clamp(0.0, 1.0);
    final cx = ax + t * dx - px, cy = ay + t * dy - py;
    return math.sqrt(cx * cx + cy * cy);
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
