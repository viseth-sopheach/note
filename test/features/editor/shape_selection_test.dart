import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/selection_handle.dart';
import 'package:quill_notes/features/editor/domain/shape_center.dart';
import 'package:quill_notes/features/editor/domain/shape_recognizer.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 's${n++}');
  });
  tearDown(() => c.dispose());

  void drag(
    double x0,
    double y0,
    double x1,
    double y1, {
    int p = 1,
    int t = 0,
  }) {
    c.beginStroke(pointer: p, x: x0, y: y0, pressure: 1, timeMs: t);
    c.extendStroke(
      pointer: p,
      x: (x0 + x1) / 2,
      y: (y0 + y1) / 2,
      pressure: 1,
      timeMs: t + 8,
    );
    c.endStroke(pointer: p, x: x1, y: y1, pressure: 1, timeMs: t + 16);
  }

  void line(double x0, double y0, double x1, double y1) {
    c.selectTool(StrokeTool.line);
    drag(x0, y0, x1, y1);
  }

  /// A tap that never selects anything: selection is done with [lasso].
  void tap(double x, double y, {int p = 9}) {
    c.beginStroke(pointer: p, x: x, y: y, pressure: 1, timeMs: 1000);
    c.endStroke(pointer: p, x: x, y: y, pressure: 1, timeMs: 1020);
  }

  void lasso(double l, double t, double r, double b) {
    c.selectTool(StrokeTool.select);
    c.beginStroke(pointer: 5, x: l, y: t, pressure: 1, timeMs: 2000);
    c.extendStroke(pointer: 5, x: r, y: t, pressure: 1, timeMs: 2001);
    c.extendStroke(pointer: 5, x: r, y: b, pressure: 1, timeMs: 2002);
    c.endStroke(pointer: 5, x: l, y: b, pressure: 1, timeMs: 2003);
  }

  /// Lasso a generous box around the stroke from (x0, y0) to (x1, y1).
  void lassoAround(
    double x0,
    double y0,
    double x1,
    double y1, {
    double pad = 12,
  }) {
    lasso(
      math.min(x0, x1) - pad,
      math.min(y0, y1) - pad,
      math.max(x0, x1) + pad,
      math.max(y0, y1) + pad,
    );
  }

  test('hold time defaults to 0.7 s', () {
    expect(c.holdDuration, const Duration(milliseconds: 700));
  });

  test('a line is a Line shape with two endpoint handles', () {
    line(0, 0, 200, 0);
    lassoAround(0, 0, 200, 0);
    expect(c.strokes.single.shape, ShapeKind.line);
    expect(c.handleSpots.map((s) => s.handle).toSet(), {
      SelectionHandle.start,
      SelectionHandle.end,
    });
  });

  test('a freehand stroke can never be selected or show handles', () {
    c.beginStroke(pointer: 1, x: 100, y: 300, pressure: 1, timeMs: 0);
    for (var i = 1; i < 40; i++) {
      c.extendStroke(
        pointer: 1,
        x: 100 + 5.0 * i,
        y: 300 - 120 * math.sin(math.pi * i / 40),
        pressure: 1,
        timeMs: i * 8,
      );
    }
    c.endStroke(pointer: 1, x: 300, y: 300, pressure: 1, timeMs: 400);
    expect(c.strokes.single.shape, isNull);

    // A tap never selects a freehand stroke.
    tap(200, 180);

    expect(c.hasSelection, isFalse);
    expect(c.handleSpots, isEmpty);
    expect(c.selectionFrame, isNull);

    // Neither does a lasso.
    lassoAround(100, 180, 300, 300, pad: 20);
    expect(c.hasSelection, isFalse);
  });

  test('hover only highlights selectable shapes', () {
    c.selectTool(StrokeTool.pen);
    c.beginStroke(pointer: 1, x: 0, y: 0, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 100, y: 0, pressure: 1, timeMs: 16);
    c.hoverAt(50, 0);
    expect(c.hoverId, isNull);

    line(0, 100, 100, 100);
    c.clearSelection();
    c.hoverAt(50, 100);
    expect(c.hoverId, 's1');
    c.hoverAt(50, 300);
    expect(c.hoverId, isNull);
  });

  test('a rectangle keeps box handles', () {
    c.selectTool(StrokeTool.rectangle);
    drag(0, 0, 100, 80);
    lassoAround(0, 0, 100, 80);
    expect(c.strokes.first.shape, ShapeKind.rectangle);
    expect(c.handleSpots, hasLength(8));
    expect(c.handleSpots.any((s) => s.handle.isEndpoint), isFalse);
  });

  test('selection frame is at least 24 px, at any zoom', () {
    line(0, 0, 200, 0);
    lassoAround(0, 0, 200, 0);
    expect(
      c.selectionFrame!.bottom - c.selectionFrame!.top,
      greaterThanOrEqualTo(24),
    );
    c.viewScale = () => 2;
    expect(
      c.selectionFrame!.bottom - c.selectionFrame!.top,
      greaterThanOrEqualTo(12),
    );
  });

  test('hit targets keep their screen size when zoomed', () {
    line(0, 0, 200, 0);
    lassoAround(0, 0, 200, 0);
    expect(c.hitsSelectionChrome(200, 13), isTrue);
    expect(c.hitsSelectionChrome(200, 40), isFalse);
    c.viewScale = () => 2;
    expect(c.hitsSelectionChrome(200, 13), isFalse);
  });

  test('dragging an endpoint keeps the other end fixed and undoes', () {
    line(0, 0, 200, 0);
    lassoAround(0, 0, 200, 0);
    c.beginStroke(pointer: 3, x: 200, y: 0, pressure: 1, timeMs: 3000);
    expect(c.isResizingSelection, isTrue);
    c.extendStroke(pointer: 3, x: 200, y: 100, pressure: 1, timeMs: 3010);
    c.endStroke(pointer: 3, x: 200, y: 100, pressure: 1, timeMs: 3020);
    final pts = c.strokes.single.points;
    expect(pts, hasLength(2));
    expect(pts.first.x, 0);
    expect(pts.first.y, 0);
    expect(pts.last.x, closeTo(200, 0.01));
    expect(pts.last.y, closeTo(100, 0.01));
    c.undo();
    expect(c.strokes.single.points.last.y, 0);
  });

  test('an ellipse gets a center dot in the same undo step', () {
    c.selectTool(StrokeTool.ellipse);
    drag(0, 0, 100, 60);
    expect(c.strokes, hasLength(2));
    expect(c.strokes.first.shape, ShapeKind.ellipse);
    final dot = c.strokes.last;
    expect(ShapeCenter.isDot(dot), isTrue);
    expect(dot.shape, isNull);
    expect(dot.points.single.x, closeTo(50, 1e-6));
    expect(dot.points.single.y, closeTo(30, 1e-6));
    c.undo();
    expect(c.strokes, isEmpty);
  });

  test('selecting or deleting a circle includes its dot', () {
    c.selectTool(StrokeTool.ellipse);
    drag(0, 0, 100, 100);
    lassoAround(0, 0, 100, 100, pad: 20);
    expect(c.selectedIds, hasLength(2));
    c.deleteSelection();
    expect(c.strokes, isEmpty);
    c.undo();
    expect(c.strokes, hasLength(2));
  });

  test('the eraser removes only the center dot', () {
    c.selectTool(StrokeTool.ellipse);
    drag(0, 0, 100, 100);
    c.selectTool(StrokeTool.eraser);
    c.beginStroke(pointer: 2, x: 50, y: 50, pressure: 1, timeMs: 5000);
    c.endStroke(pointer: 2, x: 50, y: 50, pressure: 1, timeMs: 5010);
    expect(c.strokes, hasLength(1));
    expect(ShapeCenter.isDot(c.strokes.single), isFalse);
  });

  test('lifting a finished stroke never converts it on its own', () async {
    final d = DrawingController(
      idGenerator: () => 'x',
      refineDelay: const Duration(milliseconds: 20),
      holdDuration: const Duration(seconds: 30),
    );
    addTearDown(d.dispose);
    d.beginStroke(pointer: 1, x: 300 + 100, y: 300, pressure: 1, timeMs: 0);
    for (var i = 1; i < 120; i++) {
      final a = 2 * math.pi * i / 119;
      d.extendStroke(
        pointer: 1,
        x: 300 + 100 * math.cos(a),
        y: 300 + 100 * math.sin(a),
        pressure: 1,
        timeMs: i * 8,
      );
    }
    d.endStroke(pointer: 1, x: 400, y: 300, pressure: 1, timeMs: 1000);
    final count = d.strokes.single.points.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(d.strokes.single.points.length, count);
  });
}
