import 'package:flutter_test/flutter_test.dart';
import 'package:quill_notes/features/editor/application/drawing_controller.dart';
import 'package:quill_notes/features/editor/domain/stroke_tool.dart';

void main() {
  late DrawingController c;
  var n = 0;

  setUp(() {
    n = 0;
    c = DrawingController(idGenerator: () => 'id${n++}');
  });

  tearDown(() => c.dispose());

  void drawLine(double y) {
    c.beginStroke(pointer: 1, x: 0, y: y, pressure: 1, timeMs: 0);
    c.endStroke(pointer: 1, x: 100, y: y, pressure: 1, timeMs: 16);
  }

  // Lasso around the line at y = 0 only.
  void lassoFirstLine() {
    c.selectTool(StrokeTool.select);
    c.beginStroke(pointer: 2, x: -10, y: -10, pressure: 1, timeMs: 100);
    c.extendStroke(pointer: 2, x: 110, y: -10, pressure: 1, timeMs: 101);
    c.extendStroke(pointer: 2, x: 110, y: 10, pressure: 1, timeMs: 102);
    c.endStroke(pointer: 2, x: -10, y: 10, pressure: 1, timeMs: 103);
  }

  void drag(double x1, double y1, double x2, double y2) {
    c.beginStroke(pointer: 3, x: x1, y: y1, pressure: 1, timeMs: 200);
    c.extendStroke(pointer: 3, x: x2, y: y2, pressure: 1, timeMs: 201);
    c.endStroke(pointer: 3, x: x2, y: y2, pressure: 1, timeMs: 202);
  }

  test('a lasso selects only the strokes inside it', () {
    drawLine(0);
    drawLine(100);

    lassoFirstLine();

    expect(c.selectedIds, {'id0'});
    expect(c.isDrawing, isFalse);
  });

  test('dragging the selection moves it as one undo step', () {
    drawLine(0);
    lassoFirstLine();
    final before = c.revision;

    drag(50, 0, 70, 20);

    expect(c.strokes.single.points.first.x, 20);
    expect(c.strokes.single.points.first.y, 20);
    expect(c.revision, greaterThan(before));
    expect(c.selectedIds, {'id0'});

    c.undo();
    expect(c.strokes.single.points.first.x, 0);
    expect(c.strokes.single.points.first.y, 0);

    c.redo();
    expect(c.strokes.single.points.first.x, 20);
  });

  test('dragging outside the selection starts a new lasso', () {
    drawLine(0);
    lassoFirstLine();

    drag(300, 300, 320, 320);

    expect(c.hasSelection, isFalse);
    expect(c.strokes.single.points.first.x, 0);
  });

  test('delete removes the selection and undo restores it', () {
    drawLine(0);
    drawLine(100);
    lassoFirstLine();

    c.deleteSelection();

    expect(c.strokes.map((s) => s.id), ['id1']);
    expect(c.hasSelection, isFalse);

    c.undo();
    expect(c.strokes.map((s) => s.id), ['id0', 'id1']);
  });

  test('changing tool, undo or redo clears the selection', () {
    drawLine(0);
    lassoFirstLine();
    c.selectTool(StrokeTool.pen);
    expect(c.hasSelection, isFalse);

    lassoFirstLine();
    c.undo();
    expect(c.hasSelection, isFalse);
  });

  test('cancel during a move restores the position', () {
    drawLine(0);
    lassoFirstLine();

    c.beginStroke(pointer: 3, x: 50, y: 0, pressure: 1, timeMs: 200);
    c.extendStroke(pointer: 3, x: 90, y: 40, pressure: 1, timeMs: 201);
    c.cancelStroke(3);

    expect(c.strokes.single.points.first.x, 0);
    expect(c.selectionDx, 0);
    expect(c.isDrawing, isFalse);
  });
}